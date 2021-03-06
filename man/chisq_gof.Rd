% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gof.R
\name{chisq_gof}
\alias{chisq_gof}
\title{Chi-square goodness-of-fit-test}
\usage{
chisq_gof(x, prob = NULL, weights = NULL)
}
\arguments{
\item{x}{Numeric vector, or a \code{\link{glm}}-object.}

\item{prob}{Vector of probabilities (indicating the population probabilities) of the same length
as \code{x}'s amount of categories / factor levels. Use \code{nrow(table(x))} to
determine the amount of necessary values for \code{prob}. Only used,
when \code{x} is a vector, and not a \code{glm}-object.}

\item{weights}{Vector with weights, used to weight \code{x}.}
}
\value{
For vectors, returns the object of the computed \code{\link{chisq.test}}.
          \cr \cr
          For \code{glm}-objects, an object of class \code{chisq_gof} with
          following values:
          \itemize{
           \item \code{p.value}	the p-value for the goodness-of-fit test
           \item \code{z.score} the standardized z-score for the goodness-of-fit test
           \item \code{RSS} the residual sums of squares term
           \item \code{X2} the pearson chi-squared statistic
          }
}
\description{
This method performs a Chi-square goodness-of-fit-test (GOF)
               either on a numeric vector against probabilities, or
               a Goodness-of-fit test for \code{\link{glm}}-objects for binary data.
}
\note{
For vectors, this function is a convenient function for the \code{\link{chisq.test}},
        performing goodness-of-fit test.
        \cr \cr
        For \code{glm}-objects, this function performs a goodness-of-fit test
        based on the \code{X2GOFtest} function of the \CRANpkg{binomTools} package.
        A well-fitting model shows no significant difference between
        the model and the observed data, i.e. the reported p-values should be
        greater than 0.05.
}
\examples{
data(efc)
# differing from population
chisq_gof(efc$e42dep, c(0.3,0.2,0.22,0.28))
# equal to population
chisq_gof(efc$e42dep, prop.table(table(efc$e42dep)))

# goodness-of-fit test for logistic regression
efc$services <- ifelse(efc$tot_sc_e > 0, 1, 0)
fit <- glm(services ~ neg_c_7 + c161sex + e42dep, data = efc,
           family = binomial(link = "logit"))
chisq_gof(fit)

}
