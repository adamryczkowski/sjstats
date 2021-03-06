% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/boot_ci.R
\name{boot_ci}
\alias{boot_ci}
\alias{boot_se}
\alias{boot_p}
\title{Standard error and confidence intervals for bootstrapped estimates}
\usage{
boot_ci(data, ...)

boot_se(data, ...)

boot_p(data, ...)
}
\arguments{
\item{data}{A data frame that containts the vector with bootstrapped
estimates, or directly the vector (see 'Examples').}

\item{...}{Optional, names of the variables with bootstrapped estimates.
Required, if either \code{data} is a data frame and no vector,
or if only selected variables from \code{data} should be used
in the function.}
}
\value{
A \code{\link[tibble]{tibble}} with either bootstrap standard error,
        the lower and upper confidence intervals or the p-value for all
        bootstrapped estimates.
}
\description{
Compute nonparametric bootstrap standard error, confidence
             intervals and p-value for a vector of bootstrap replicate
             estimates.
}
\details{
The methods require one or more vectors of bootstrap replicate estimates
         as input. \code{boot_se()} computes the nonparametric bootstrap
         standard error by calculating the standard deviation of the input
         vector. The mean value of the input vector and its standard error is
         used by \code{boot_ci()} to calculate the lower and upper confidence interval, assuming
         a t-distribution of bootstrap estimate replicates. P-values
         from \code{boot_p()} are also based on t-statistics, assuming normal
         distribution.
}
\examples{
data(efc)
bs <- bootstrap(efc, 100)

# now run models for each bootstrapped sample
bs$models <- lapply(bs$strap, function(x) lm(neg_c_7 ~ e42dep + c161sex, data = x))

# extract coefficient "dependency" and "gender" from each model
bs$dependency <- unlist(lapply(bs$models, function(x) coef(x)[2]))
bs$gender <- unlist(lapply(bs$models, function(x) coef(x)[3]))

# get bootstrapped confidence intervals
boot_ci(bs$dependency)

# compare with model fit
fit <- lm(neg_c_7 ~ e42dep + c161sex, data = efc)
confint(fit)[2, ]

# alternative function calls.
boot_ci(bs$dependency)
boot_ci(bs, dependency)
boot_ci(bs, dependency, gender)


# compare coefficients
mean(bs$dependency)
coef(fit)[2]

# bootstrap() and boot_ci() work fine within pipe-chains
library(dplyr)
efc \%>\%
  bootstrap(100) \%>\%
  mutate(models = lapply(.$strap, function(x) {
    lm(neg_c_7 ~ e42dep + c161sex, data = x)
  })) \%>\%
  mutate(dependency = unlist(lapply(.$models, function(x) coef(x)[2]))) \%>\%
  boot_ci(dependency)


# check p-value
boot_p(bs$gender)
summary(fit)$coefficients[3, ]


# 'spread_coef()' from the 'sjmisc'-package makes it easy to generate
# bootstrapped statistics like confidence intervals or p-values
library(dplyr)
library(sjmisc)
efc \%>\%
  # generate bootstrap replicates
  bootstrap(100) \%>\%
  # apply lm to all bootstrapped data sets
  mutate(models = lapply(.$strap, function(x) {
    lm(neg_c_7 ~ e42dep + c161sex + c172code, data = x)
  })) \%>\%
  # spread model coefficient for all 100 models
  spread_coef(models) \%>\%
  # compute the CI for all bootstrapped model coefficients
  boot_ci(e42dep, c161sex, c172code)

# or...
efc \%>\%
  # generate bootstrap replicates
  bootstrap(100) \%>\%
  # apply lm to all bootstrapped data sets
  mutate(models = lapply(strap, function(x) {
    lm(neg_c_7 ~ e42dep + c161sex + c172code, data = x)
  })) \%>\%
  # spread model coefficient for all 100 models
  spread_coef(models, append = FALSE) \%>\%
  # compute the CI for all bootstrapped model coefficients
  boot_ci()

}
\references{
Carpenter J, Bithell J. Bootstrap confdence intervals: when, which, what? A practical guide for medical statisticians. Statist. Med. 2000; 19:1141-1164
}
\seealso{
\code{\link{bootstrap}} to generate nonparametric bootstrap samples.
}
