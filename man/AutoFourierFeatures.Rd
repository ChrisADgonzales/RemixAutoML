% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/EconometricsFunctions.R
\name{AutoFourierFeatures}
\alias{AutoFourierFeatures}
\title{AutoFourierFeatures}
\usage{
AutoFourierFeatures(
  data,
  FourierPairs = NULL,
  FCPeriods = NULL,
  Time_Unit = NULL,
  TargetColumn = NULL,
  DateColumn = NULL,
  GroupVariable = NULL,
  xregs = NonGroupDateNames
)
}
\arguments{
\item{data}{The source data}

\item{FourierPairs}{A number indicating the max number of fourier pairs that will be built}

\item{FCPeriods}{Number of periods}

\item{Time_Unit}{Agg level}

\item{TargetColumn}{The name of your target column}

\item{DateColumn}{The name of your date column}

\item{GroupVariable}{The name of your group variable}

\item{xregs}{Extra data to merge in}
}
\description{
#' AutoFourierFeatures
}
\seealso{
Other Feature Engineering Helper: 
\code{\link{ID_BuildTrainDataSets}()},
\code{\link{ID_MetadataGenerator}()},
\code{\link{ID_TrainingDataGenerator2}()},
\code{\link{ID_TrainingDataGenerator}()}
}
\author{
Adrian Antico
}
\concept{Feature Engineering Helper}
