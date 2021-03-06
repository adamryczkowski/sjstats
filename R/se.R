utils::globalVariables(c("strap", "models", "estimate"))

#' @title Standard Error for variables or coefficients
#' @name se
#' @description Compute standard error for a variable, for all variables
#'                of a data frame, for joint random and fixed effects
#'                coefficients of (non-/linear) mixed models, the adjusted
#'                standard errors for generalized linear (mixed) models, or
#'                for intraclass correlation coefficients (ICC).
#'
#' @param x (Numeric) vector, a data frame, an \code{lm} or \code{glm}-object,
#'          a \code{merMod}-object as returned by the functions from the
#'          \pkg{lme4}-package, an ICC object (as obtained by the
#'          \code{\link{icc}}-function) or a list with estimate and p-value.
#'          For the latter case, the list must contain elements named
#'          \code{estimate} and \code{p.value} (see 'Examples' and 'Details').
#' @param nsim Numeric, the number of simulations for calculating the
#'          standard error for intraclass correlation coefficients, as
#'          obtained by the \code{\link{icc}}-function.
#'
#' @return The standard error of \code{x}.
#'
#' @note Computation of standard errors for coefficients of mixed models
#'         is based \href{http://stackoverflow.com/questions/26198958/extracting-coefficients-and-their-standard-error-from-lme}{on this code}.
#'         \cr \cr
#'         Standard errors for generalized linear (mixed) models are
#'         approximations based on the delta method (Oehlert 1992).
#'
#' @details For linear mixed models, this function computes the standard errors
#'            for joint (sums of) random and fixed effects coefficients (unlike
#'            \code{\link[arm]{se.coef}}, which returns the standard error
#'            for fixed and random effects separately). Hence, \code{se()}
#'            returns the appropriate standard errors for \code{\link[lme4]{coef.merMod}}.
#'            \cr \cr
#'            For generalized linear models or generalized linear mixed models,
#'            approximated standard errors, using the delta method for transformed
#'            regression parameters are returned (Oehlert 1992). For generalized
#'            linear mixed models, the standard errors refer to the fixed effects
#'            only.
#'            \cr \cr
#'            The standard error for the \code{\link{icc}} is based on bootstrapping,
#'            thus, the \code{nsim}-argument is required. See 'Examples'.
#'            \cr \cr
#'            \code{se()} also returns the standard error of an estimate (regression
#'            coefficient) and p-value, assuming a normal distribution to compute
#'            the z-score from the p-value (formula in short: \code{b / qnorm(p / 2)}).
#'            See 'Examples'.
#'
#' @references Oehlert GW. 1992. A note on the delta method. American Statistician 46(1).
#'
#' @examples
#' # compute standard error for vector
#' se(rnorm(n = 100, mean = 3))
#'
#' # compute standard error for each variable in a data frame
#' data(efc)
#' se(efc[, 1:3])
#'
#' # compute standard error for merMod-coefficients
#' library(lme4)
#' fit <- lmer(Reaction ~ Days + (Days | Subject), sleepstudy)
#' se(fit)
#'
#' # compute odds-ratio adjusted standard errors, based on delta method
#' # with first-order Taylor approximation.
#' data(efc)
#' efc$services <- sjmisc::dicho(efc$tot_sc_e, dich.by = 0)
#' fit <- glm(services ~ neg_c_7 + c161sex + e42dep,
#'            data = efc, family = binomial(link = "logit"))
#' se(fit)
#'
#' # compute odds-ratio adjusted standard errors for generalized
#' # linear mixed model, also based on delta method
#' library(lme4)
#' library(sjmisc)
#' # create binary response
#' sleepstudy$Reaction.dicho <- dicho(sleepstudy$Reaction, dich.by = "median")
#' fit <- glmer(Reaction.dicho ~ Days + (Days | Subject),
#'              data = sleepstudy, family = binomial("logit"))
#' se(fit)
#'
#' # compute standard error from regression coefficient and p-value
#' se(list(estimate = .3, p.value = .002))
#'
#' \dontrun{
#' # compute standard error of ICC for the linear mixed model
#' icc(fit)
#' se(icc(fit))
#'
#' # the standard error for the ICC can be computed manually in this way,
#' # taking the fitted model example from above
#' library(dplyr)
#' dummy <- sleepstudy %>%
#'   # generate 100 bootstrap replicates of dataset
#'   bootstrap(100) %>%
#'   # run mixed effects regression on each bootstrap replicate
#'   mutate(models = lapply(.$strap, function(x) {
#'     lmer(Reaction ~ Days + (Days | Subject), data = x)
#'   })) %>%
#'   # compute ICC for each "bootstrapped" regression
#'   mutate(icc = unlist(lapply(.$models, icc)))
#' # now compute SE and p-values for the bootstrapped ICC, values
#' # may differ from above example due to random seed
#' boot_se(dummy, icc)
#' boot_p(dummy, icc)}
#'
#'
#' @importFrom stats qnorm vcov
#' @importFrom broom tidy
#' @importFrom dplyr mutate select_
#' @export
se <- function(x, nsim = 100) {
  if (inherits(x, c("lmerMod", "nlmerMod", "merModLmerTest"))) {
    # return standard error for (linear) mixed models
    return(std_merMod(x))
  } else if (inherits(x, "icc.lme4")) {
    # we have a ICC object, so do bootstrapping and compute SE for ICC
    return(std_e_icc(x, nsim))
  } else if (inherits(x, c("glm", "glmerMod"))) {
    # for glm, we want to exponentiate coefficients to get odds ratios, however
    # 'exponentiate'-argument currently not works for lme4-tidiers
    # so we need to do this manually for glmer's
    tm <- broom::tidy(x, effects = "fixed")
    tm$estimate <- exp(tm$estimate)
    return(
      tm %>%
        # vcov for merMod returns a dpoMatrix-object, so we need
        # to coerce to regular matrix here.
        dplyr::mutate(or.se = sqrt(estimate ^ 2 * diag(as.matrix(stats::vcov(x))))) %>%
        dplyr::select_("term", "estimate", "or.se") %>%
        sjmisc::var_rename(or.se = "std.error")
    )
  } else if (inherits(x, "lm")) {
    # for convenience reasons, also return se for simple linear models
    return(x %>%
             broom::tidy(effects = "fixed") %>%
             dplyr::select_("term", "estimate", "std.error")
    )
  } else if (is.matrix(x) || is.data.frame(x)) {
    # init return variables
    stde <- c()
    stde_names <- c()

    # iterate all columns
    for (i in seq_len(ncol(x))) {
      # get and save standard error for each variable
      # of the data frame
      stde <- c(stde, std_e_helper(x[[i]]))
      # save column name as variable name
      stde_names <- c(stde_names, colnames(x)[i])
    }

    # set names to return vector
    names(stde) <- stde_names

    # return results
    return(stde)
  } else if (is.list(x)) {
    # compute standard error from regression coefficient and p-value
    return(x$estimate / abs(stats::qnorm(x$p.value / 2)))
  } else {
    # standard error for a variable
    return(std_e_helper(x))
  }
}

std_e_helper <- function(x) sqrt(var(x, na.rm = TRUE) / length(stats::na.omit(x)))


#' @importFrom stats coef setNames
#' @importFrom lme4 ranef
std_merMod <- function(fit) {
  se.merMod <- list()

  # get coefficients
  cc <- stats::coef(fit)

  # get names of intercepts
  inames <- names(cc)

  # variances of fixed effects
  fixed.vars <- diag(as.matrix(lme4::vcov.merMod(fit)))

  # extract variances of conditional modes
  r1 <- lme4::ranef(fit, condVar = TRUE)

  # we may have multiple random intercepts, iterate all
  for (i in seq_len(length(cc))) {
    cmode.vars <- t(apply(attr(r1[[i]], "postVar"), 3, diag))
    seVals <- sqrt(sweep(cmode.vars, 2, fixed.vars, "+"))

    # add results to return list
    se.merMod[[length(se.merMod) + 1]] <- stats::setNames(as.vector(seVals[1, ]),
                                                          c("intercept_se", "slope_se"))
  }

  # set names of list
  names(se.merMod) <- inames
  return(se.merMod)
}



#' @importFrom dplyr "%>%"
#' @importFrom stats model.frame
std_e_icc <- function(x, nsim) {
  # check whether model is still in environment?
  obj.name <- attr(x, ".obj.name", exact = T)
  if (!exists(obj.name, envir = globalenv()))
    stop(sprintf("Can't find merMod-object `%s` (that was used to compute the ICC) in the environment.", obj.name), call. = F)

  # get object, see whether formulas match
  fitted.model <- globalenv()[[obj.name]]
  model.formula <- attr(x, "formula", exact = T)
  if (!identical(model.formula, formula(fitted.model)))
    stop(sprintf("merMod-object `%s` was fitted with a different formula than ICC-model", obj.name), call. = F)

  # get model family, we may have glmer
  model.family <- attr(x, "family", exact = T)

  # check for all required arguments
  if (missing(nsim) || is.null(nsim)) nsim <- 100

  # get ICC, and compute bootstrapped SE, than return both
  bstr <- bootstr_icc_se(stats::model.frame(fitted.model), nsim, model.formula, model.family)

  # now compute SE and p-values for the bootstrapped ICC
  res <- data.frame(model = obj.name,
                    icc = as.vector(x),
                    std.err = boot_se(bstr, icc)[["std.err"]],
                    p.value = boot_p(bstr, icc)[["p.value"]])
  structure(class = "se.icc.lme4", list(result = res, bootstrap_data = bstr))
}



#' @importFrom dplyr mutate
#' @importFrom lme4 lmer glmer
#' @importFrom utils txtProgressBar
bootstr_icc_se <- function(dd, nsim, formula, model.family) {
  # create progress bar
  pb <- utils::txtProgressBar(min = 1, max = nsim, style = 3)

  # generate bootstraps
  dummy <- dd %>%
    bootstrap(nsim) %>%
    dplyr::mutate(models = lapply(strap, function(x) {
      # update progress bar
      utils::setTxtProgressBar(pb, x$resample.id)
      # check model family, then compute mixed model
      if (model.family == "gaussian")
        lme4::lmer(formula, data = x)
      else
        lme4::glmer(formula, data = x, family = model.family)
    })) %>%
    # compute ICC for each "bootstrapped" regression
    dplyr::mutate(icc = unlist(lapply(models, icc)))

  # close progresss bar
  close(pb)
  return(dummy)
}