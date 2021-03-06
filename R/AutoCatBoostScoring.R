#' AutoCatBoostScoring
#'
#' AutoCatBoostScoring is an automated scoring function that compliments the AutoCatBoost model training functions. This function requires you to supply features for scoring. It will run ModelDataPrep() to prepare your features for catboost data conversion and scoring.
#'
#' @author Adrian Antico
#' @family Automated Model Scoring
#' @param TargetType Set this value to "regression", "classification", "multiclass", or "multiregression" to score models built using AutoCatBoostRegression(), AutoCatBoostClassify() or AutoCatBoostMultiClass().
#' @param ScoringData This is your data.table of features for scoring. Can be a single row or batch.
#' @param FeatureColumnNames Supply either column names or column numbers used in the AutoCatBoostRegression() function
#' @param FactorLevelsList List of factors levels to DummifyDT()
#' @param IDcols Supply ID column numbers for any metadata you want returned with your predicted values
#' @param OneHot Passsed to DummifyD
#' @param ReturnShapValues Set to TRUE to return a data.table of feature contributions to all predicted values generated
#' @param ModelObject Supply the model object directly for scoring instead of loading it from file. If you supply this, ModelID and ModelPath will be ignored.
#' @param ModelPath Supply your path file used in the AutoCatBoost__() function
#' @param ModelID Supply the model ID used in the AutoCatBoost__() function
#' @param ReturnFeatures Set to TRUE to return your features with the predicted values.
#' @param MultiClassTargetLevels For use with AutoCatBoostMultiClass(). If you saved model objects then this scoring function will locate the target levels file. If you did not save model objects, you can supply the target levels returned from AutoCatBoostMultiClass().
#' @param TransformNumeric Set to TRUE if you have features that were transformed automatically from an Auto__Regression() model AND you haven't already transformed them.
#' @param BackTransNumeric Set to TRUE to generate back-transformed predicted values. Also, if you return features, those will also be back-transformed.
#' @param TargetColumnName Input your target column name used in training if you are utilizing the transformation service
#' @param TransformationObject Set to NULL if you didn't use transformations or if you want the function to pull from the file output from the Auto__Regression() function. You can also supply the transformation data.table object with the transformation details versus having it pulled from file.
#' @param TransID Set to the ID used for saving the transformation data.table object or set it to the ModelID if you are pulling from file from a build with Auto__Regression().
#' @param TransPath Set the path file to the folder where your transformation data.table detail object is stored. If you used the Auto__Regression() to build, set it to the same path as ModelPath.
#' @param MDP_Impute Set to TRUE if you did so for modeling and didn't do so before supplying ScoringData in this function
#' @param MDP_CharToFactor Set to TRUE to turn your character columns to factors if you didn't do so to your ScoringData that you are supplying to this function
#' @param MDP_RemoveDates Set to TRUE if you have date of timestamp columns in your ScoringData
#' @param MDP_MissFactor If you set MDP_Impute to TRUE, supply the character values to replace missing values with
#' @param MDP_MissNum If you set MDP_Impute to TRUE, supply a numeric value to replace missing values with
#' @param RemoveModel Set to TRUE if you want the model removed immediately after scoring
#' @examples
#' \dontrun{
#'
#' # Create some dummy correlated data
#' data <- RemixAutoML::FakeDataGenerator(
#'   Correlation = 0.85,
#'   N = 10000,
#'   ID = 2,
#'   ZIP = 0,
#'   AddDate = FALSE,
#'   Classification = FALSE,
#'   MultiClass = FALSE)
#'
#' # Train a Multiple Regression Model (two target variables)
#' TestModel <- RemixAutoML::AutoCatBoostRegression(
#'
#'   # GPU or CPU and the number of available GPUs
#'   task_type = "GPU",
#'   NumGPUs = 1,
#'
#'   # Metadata arguments
#'   ModelID = "Test_Model_1",
#'   model_path = normalizePath("./"),
#'   metadata_path = NULL,
#'   SaveModelObjects = FALSE,
#'   ReturnModelObjects = TRUE,
#'
#'   # Data arguments
#'   data = data,
#'   TrainOnFull = FALSE,
#'   ValidationData = NULL,
#'   TestData = NULL,
#'   Weights = NULL,
#'   DummifyCols = FALSE,
#'   TargetColumnName = c("Adrian","Independent_Variable1"),
#'   FeatureColNames = names(data)[!names(data) %in%
#'     c("IDcol_1","IDcol_2","Adrian")],
#'   PrimaryDateColumn = NULL,
#'   IDcols = c("IDcol_1","IDcol_2"),
#'   TransformNumericColumns = NULL,
#'   Methods = c("BoxCox","Asinh","Asin","Log","LogPlus1",
#'     "Logit","YeoJohnson"),
#'
#'   # Model evaluation
#'   eval_metric = "MultiRMSE",
#'   eval_metric_value = 1.5,
#'   loss_function = "MultiRMSE",
#'   loss_function_value = 1.5,
#'   MetricPeriods = 10L,
#'   NumOfParDepPlots = ncol(data)-1L-2L,
#'   EvalPlots = TRUE,
#'
#'   # Grid tuning
#'   PassInGrid = NULL,
#'   GridTune = FALSE,
#'   MaxModelsInGrid = 100L,
#'   MaxRunsWithoutNewWinner = 100L,
#'   MaxRunMinutes = 60*60,
#'   Shuffles = 4L,
#'   BaselineComparison = "default",
#'
#'   # ML Args
#'   langevin = TRUE,
#'   diffusion_temperature = 10000,
#'   Trees = 250,
#'   Depth = 6,
#'   L2_Leaf_Reg = 3.0,
#'   RandomStrength = 1,
#'   BorderCount = 128,
#'   LearningRate = seq(0.01,0.10,0.01),
#'   RSM = c(0.80, 0.85, 0.90, 0.95, 1.0),
#'   BootStrapType = c("Bayesian","Bernoulli","Poisson","MVS","No"),
#'   GrowPolicy = c("SymmetricTree", "Depthwise", "Lossguide"))
#'
#' # Output
#' TestModel$Model
#' TestModel$ValidationData
#' TestModel$EvaluationPlot
#' TestModel$EvaluationBoxPlot
#' TestModel$EvaluationMetrics
#' TestModel$VariableImportance
#' TestModel$InteractionImportance
#' TestModel$ShapValuesDT
#' TestModel$VI_Plot
#' TestModel$PartialDependencePlots
#' TestModel$PartialDependenceBoxPlots
#' TestModel$GridList
#' TestModel$ColNames
#' TestModel$TransformationResults
#'
#' # Score a multiple regression model
#' Preds <- RemixAutoML::AutoCatBoostScoring(
#'   TargetType = "multiregression",
#'   ScoringData = data,
#'   FeatureColumnNames = names(data)[!names(data) %in%
#'     c("IDcol_1", "IDcol_2","Adrian")],
#'   FactorLevelsList = TestModel$FactorLevelsList,
#'   IDcols = c("IDcol_1","IDcol_2"),
#'   OneHot = FALSE,
#'   ReturnShapValues = TRUE,
#'   ModelObject = TestModel$Model,
#'   ModelPath = NULL, #normalizePath("./"),
#'   ModelID = "Test_Model_1",
#'   ReturnFeatures = TRUE,
#'   MultiClassTargetLevels = NULL,
#'   TransformNumeric = FALSE,
#'   BackTransNumeric = FALSE,
#'   TargetColumnName = NULL,
#'   TransformationObject = NULL,
#'   TransID = NULL,
#'   TransPath = NULL,
#'   MDP_Impute = TRUE,
#'   MDP_CharToFactor = TRUE,
#'   MDP_RemoveDates = TRUE,
#'   MDP_MissFactor = "0",
#'   MDP_MissNum = -1,
#'   RemoveModel = FALSE)
#' }
#' @return A data.table of predicted values with the option to return model features as well.
#' @export
AutoCatBoostScoring <- function(TargetType = NULL,
                                ScoringData = NULL,
                                FeatureColumnNames = NULL,
                                FactorLevelsList = NULL,
                                IDcols = NULL,
                                OneHot = FALSE,
                                ReturnShapValues = FALSE,
                                ModelObject = NULL,
                                ModelPath = NULL,
                                ModelID = NULL,
                                ReturnFeatures = TRUE,
                                MultiClassTargetLevels = NULL,
                                TransformNumeric = FALSE,
                                BackTransNumeric = FALSE,
                                TargetColumnName = NULL,
                                TransformationObject = NULL,
                                TransID = NULL,
                                TransPath = NULL,
                                MDP_Impute = TRUE,
                                MDP_CharToFactor = TRUE,
                                MDP_RemoveDates = TRUE,
                                MDP_MissFactor = "0",
                                MDP_MissNum = -1,
                                RemoveModel = FALSE) {

  # Load catboost----
  loadNamespace(package = "catboost")

  # data.table optimize----
  if(parallel::detectCores() > 10) data.table::setDTthreads(threads = max(1L, parallel::detectCores() - 2L)) else data.table::setDTthreads(threads = max(1L, parallel::detectCores()))

  # Check arguments----
  if(is.null(ScoringData)) return("ScoringData cannot be NULL")
  if(!data.table::is.data.table(ScoringData)) data.table::setDT(ScoringData)
  if(!is.logical(MDP_Impute)) return("MDP_Impute (ModelDataPrep) should be TRUE or FALSE")
  if(!is.logical(MDP_CharToFactor)) return("MDP_CharToFactor (ModelDataPrep) should be TRUE or FALSE")
  if(!is.logical(MDP_RemoveDates)) return("MDP_RemoveDates (ModelDataPrep) should be TRUE or FALSE")
  if(!is.character(MDP_MissFactor) & !is.factor(MDP_MissFactor)) return("MDP_MissFactor should be a character or factor value")
  if(!is.numeric(MDP_MissNum)) return("MDP_MissNum should be a numeric or integer value")

  # Pull in ColNames----
  if(is.null(FeatureColumnNames) & !is.null(ModelPath)) FeatureColumnNames <- data.table::fread(file = file.path(ModelPath, paste0(ModelID,"_ColNames.csv")))

  # Pull In Transformation Object----
  if(is.null(TransformationObject)) {
    if(TransformNumeric | BackTransNumeric) {
      if(is.null(TargetColumnName)) return("TargetColumnName needs to be supplied")
      TransformationObject <- data.table::fread(file.path(normalizePath(TransPath), paste0(TransID, "_transformation.csv")))
    }
  }

  # Identify column numbers for factor variables----
  CatFeatures <- sort(c(as.numeric(which(sapply(ScoringData, is.factor))), as.numeric(which(sapply(ScoringData, is.character)))))

  # DummifyDT categorical columns----
  if(!is.null(CatFeatures) & tolower(TargetType) == "multiregression") {
    if(!is.null(FactorLevelsList)) {
      ScoringData <- DummifyDT(
        data = ScoringData,
        cols = if(!is.character(CatFeatures)) names(ScoringData)[CatFeatures] else CatFeatures,
        KeepFactorCols = FALSE,
        OneHot = OneHot,
        SaveFactorLevels = FALSE,
        SavePath = ModelPath,
        ImportFactorLevels = FALSE,
        FactorLevelsList = FactorLevelsList,
        ReturnFactorLevels = FALSE,
        ClustScore = FALSE,
        GroupVar = TRUE)
    } else {
      ScoringData <- DummifyDT(
        data = ScoringData,
        cols = if(!is.character(CatFeatures)) names(ScoringData)[CatFeatures] else CatFeatures,
        KeepFactorCols = FALSE,
        OneHot = OneHot,
        SaveFactorLevels = FALSE,
        SavePath = ModelPath,
        ImportFactorLevels = TRUE,
        ReturnFactorLevels = FALSE,
        ClustScore = FALSE,
        GroupVar = TRUE)
    }

    # Return value to CatFeatures as if there are no categorical variables
    CatFeatures <- numeric(0)
  }

  # Convert CatFeatures to 1-indexed----
  if(length(CatFeatures) > 0) for(i in seq_len(length(CatFeatures))) CatFeatures[i] <- CatFeatures[i] - 1L

  # ModelDataPrep Check----
  ScoringData <- ModelDataPrep(
    data = ScoringData,
    Impute = MDP_Impute,
    CharToFactor = MDP_CharToFactor,
    RemoveDates = MDP_RemoveDates,
    MissFactor = MDP_MissFactor,
    MissNum = MDP_MissNum)

  # IDcols conversion----
  if(is.numeric(IDcols) || is.integer(IDcols)) IDcols <- names(data)[IDcols]

  # Apply Transform Numeric Variables----
  if(TransformNumeric) {
    tempTrans <- data.table::copy(TransformationObject)
    tempTrans <- tempTrans[ColumnName != eval(TargetColumnName)]
    ScoringData <- AutoTransformationScore(
      ScoringData = ScoringData,
      FinalResults = tempTrans,
      Type = "Apply",
      TransID = TransID,
      Path = TransPath)
  }

  # Convert FeatureColumnNames to Character Names----
  if(data.table::is.data.table(FeatureColumnNames)) {
    FeatureColumnNames <- FeatureColumnNames[[1L]]
  } else if(is.numeric(FeatureColumnNames)) {
    FeatureColumnNames <- names(ScoringData)[FeatureColumnNames]
  }

  # Remove Target from FeatureColumnNames----
  if(TransformNumeric | BackTransNumeric) if(!is.null(TargetColumnName)) if(TargetColumnName %chin% FeatureColumnNames) FeatureColumnNames <- FeatureColumnNames[!(TargetColumnName == FeatureColumnNames)]

  # Subset Columns Needed----
  FeatureColumnNames <- names(ScoringData)[!names(ScoringData) %chin% c(IDcols)]
  keep1 <- c(FeatureColumnNames)
  if(!is.null(IDcols)) keep <- c(IDcols, FeatureColumnNames) else keep <- c(FeatureColumnNames)
  ScoringData <- ScoringData[, ..keep]
  if(!is.null(IDcols)) {
    ScoringMerge <- data.table::copy(ScoringData)
    keep <- c(keep1)
    ScoringData <- ScoringData[, ..keep]
  } else {
    ScoringMerge <- data.table::copy(ScoringData)
  }

  # Initialize Catboost Data Conversion----
  if(!is.null(CatFeatures)) {
    ScoringPool <- catboost::catboost.load_pool(ScoringData, cat_features = CatFeatures)
  } else {
    ScoringPool <- catboost::catboost.load_pool(ScoringData)
  }

  # Load model----
  if(!is.null(ModelObject)) {
    model <- ModelObject
  } else {
    model <- tryCatch({catboost::catboost.load_model(file.path(normalizePath(ModelPath), ModelID))}, error = function(x) NULL)
    if(is.null(model)) return("Model not found in ModelPath")
  }

  # Score model----
  if(tolower(TargetType) == "regression" || tolower(TargetType) == "multiregression") {
    predict <- data.table::as.data.table(
      catboost::catboost.predict(
        model = model,
        pool = ScoringPool,
        prediction_type = "RawFormulaVal",
        thread_count = -1L))
  } else if(tolower(TargetType) == "classification") {
    predict <- data.table::as.data.table(
      catboost::catboost.predict(
        model = model,
        pool = ScoringPool,
        prediction_type = "Probability"))
  } else if(tolower(TargetType) == "multiclass") {
    predict <- data.table::as.data.table(cbind(
      1 + catboost::catboost.predict(
        model = model,
        pool = ScoringPool,
        prediction_type = "Class"),
      catboost::catboost.predict(
        model = model,
        pool = ScoringPool,
        prediction_type = "Probability")))
  }

  # Create ShapValues ----
  if(ReturnShapValues & !(tolower(TargetType) %chin% c("multiregression","multiclass"))) {
    ShapValues <- data.table::as.data.table(catboost::catboost.get_feature_importance(model, pool = ScoringPool, type = "ShapValues"))
    data.table::setnames(ShapValues, names(ShapValues), c(paste0("Shap_",FeatureColumnNames), "Predictions"))
    ShapValues[, Predictions := NULL]
  }

  # Remove Model----
  if(RemoveModel) rm(model)

  # Score model-----
  if(tolower(TargetType) == "multiclass") {
    data.table::setnames(predict, "V1", "Predictions")
    if(!is.null(MultiClassTargetLevels)) {
      TargetLevels <- MultiClassTargetLevels
    } else {
      TargetLevels <- data.table::fread(file.path(normalizePath(ModelPath), paste0(ModelID, "_TargetLevels.csv")))
    }
    k <- 1L
    for(name in as.character(TargetLevels[[1L]])) {
      k <- k + 1L
      data.table::setnames(predict, paste0("V", k), name)
    }
    predict <- merge(
      predict,
      TargetLevels,
      by.x = "Predictions",
      by.y = "NewLevels",
      all = FALSE)
    predict[, Predictions := OriginalLevels][, OriginalLevels := NULL]
  }

  # Rename predicted value----
  if(tolower(TargetType) %chin% c("regression")) data.table::setnames(predict, "V1", "Predictions")
  if(tolower(TargetType) %chin% c("multiregression")) for(i in seq_len(ncol(predict))) data.table::setnames(predict, paste0("V",i), paste0("Predictions.V",i))
  if(tolower(TargetType) == "classification") data.table::setnames(predict, "V1", "p1")

  # Merge features back on----
  if(ReturnFeatures & tolower(TargetType) != "multiclass") predict <- cbind(predict, ScoringMerge)

  # Back Transform Numeric Variables----
  if(BackTransNumeric & !tolower(TargetType) == "multiregression") {
    grid_trans_results <- data.table::copy(TransformationObject)
    data.table::set(grid_trans_results, i = which(grid_trans_results[["ColumnName"]] == eval(TargetColumnName)), j = "ColumnName", value = "Predictions")
    grid_trans_results <- grid_trans_results[ColumnName != eval(TargetColumnName)]

    # Run Back-Transform----
    predict <- AutoTransformationScore(
      ScoringData = predict,
      Type = "Inverse",
      FinalResults = grid_trans_results,
      TransID = NULL,
      Path = NULL)
  }

  # Garbage Collection----
  gc()

  # Return data----
  if(ReturnShapValues & !tolower(TargetType) == "multiregression") {
    return(cbind(predict, ShapValues))
  } else {
    return(predict)
  }
}
