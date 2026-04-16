library(randomForest)
library(caret)
library(dplyr)
library(ggplot2)
library(pROC)

if (!file.exists("customer_churn.csv")) {
  stop("File not found: customer_churn.csv")
}

data <- read.csv("customer_churn.csv", stringsAsFactors = FALSE)

data$Churn <- factor(data$Churn.Label, levels = c("No", "Yes"))

drop_cols <- c(
  "CustomerID", "Country", "State", "Count",
  "Lat.Long", "Latitude", "Longitude",
  "Churn.Label", "Churn.Value", "Churn.Score", "Churn.Reason"
)

data <- data[, !(names(data) %in% drop_cols)]

# Fix high-cardinality columns
if ("City" %in% names(data)) {
  data$City <- as.numeric(factor(data$City))
}
if ("Zip.Code" %in% names(data)) {
  data$Zip.Code <- as.numeric(factor(data$Zip.Code))
}

char_cols <- sapply(data, is.character)
data[, char_cols] <- lapply(data[, char_cols], factor)

data[data == ""] <- NA
data <- na.omit(data)

set.seed(123)
index <- createDataPartition(data$Churn, p = 0.7, list = FALSE)
train <- data[index, ]
test  <- data[-index, ]

rf_model <- randomForest(
  Churn ~ .,
  data = train,
  ntree = 300,
  mtry = floor(sqrt(ncol(train) - 1)),
  importance = TRUE
)

rf_pred <- predict(rf_model, newdata = test)

rf_results <- confusionMatrix(
  rf_pred,
  test$Churn,
  positive = "Yes"
)

print(rf_results)

# ✅ FIXED ROC SECTION
rf_prob <- predict(rf_model, newdata = test, type = "prob")
rf_prob <- as.matrix(rf_prob)
prob_yes <- rf_prob[, which(colnames(rf_prob) == "Yes")]

roc_obj <- roc(test$Churn, prob_yes)
plot(roc_obj, col = "blue", main = "ROC Curve")

auc_value <- auc(roc_obj)
cat("\nAUC Score:", auc_value, "\n")

# Feature importance
importance_df <- as.data.frame(importance(rf_model))
importance_df$Feature <- rownames(importance_df)

if ("MeanDecreaseGini" %in% colnames(importance_df)) {
  importance_df$Importance <- importance_df$MeanDecreaseGini
} else {
  importance_df$Importance <- importance_df[, ncol(importance_df)]
}

importance_plot <- ggplot(
  importance_df,
  aes(x = reorder(Feature, Importance), y = Importance)
) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Feature Importance (Random Forest)",
    x = "Features",
    y = "Importance"
  ) +
  theme_minimal()

print(importance_plot)