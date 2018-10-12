-- ######################################################################################################################################
-- 
-- ######################################################################################################################################
USE TutorialDB;

DROP TABLE IF EXISTS rental_py_models;
GO
CREATE TABLE rental_py_models (
	model_name VARCHAR(30) NOT NULL DEFAULT('default model') PRIMARY KEY,
	model VARBINARY(MAX) NOT NULL
);
GO

-- ######################################################################################################################################
-- 
-- ######################################################################################################################################


-- Stored procedure that trains and generates a Python model using the rental_data and a decision tree algorithm
DROP PROCEDURE IF EXISTS generate_rental_py_model;
go
CREATE PROCEDURE generate_rental_py_model (@trained_model varbinary(max) OUTPUT)
AS
BEGIN
    EXECUTE sp_execute_external_script
      @language = N'Python'
    , @script = N'
from sklearn.linear_model import LinearRegression
import pickle

df = rental_train_data

# Get all the columns from the dataframe.
columns = df.columns.tolist()

# Store the variable well be predicting on.
target = "RentalCount"

# Initialize the model class.
lin_model = LinearRegression()

# Fit the model to the training data.
lin_model.fit(df[columns], df[target])

#Before saving the model to the DB table, we need to convert it to a binary object
trained_model = pickle.dumps(lin_model)'

, @input_data_1 = N'select "RentalCount", "Year", "Month", "Day", "WeekDay", "Snow", "Holiday" from dbo.rental_data where Year < 2015'
, @input_data_1_name = N'rental_train_data'
, @params = N'@trained_model varbinary(max) OUTPUT'
, @trained_model = @trained_model OUTPUT;
END;
GO

--STEP 3 - Save model to table
TRUNCATE TABLE rental_py_models;

DECLARE @model VARBINARY(MAX);
EXEC generate_rental_py_model @model OUTPUT;

INSERT INTO rental_py_models (model_name, model) VALUES('linear_model2', @model);

-- ###########################
-- Lets take a look at the model which was just created. 
-- This is a serialised version of our model. It has been pickled.
SELECT * FROM rental_py_models

-- ###############################

DROP PROCEDURE IF EXISTS py_predict_rentalcount;
GO
CREATE PROCEDURE py_predict_rentalcount (@model varchar(100))
AS
BEGIN
	DECLARE @py_model varbinary(max) = (select model from rental_py_models where model_name = @model);

	EXEC sp_execute_external_script
				@language = N'Python',
				@script = N'

# Import the scikit-learn function to compute error.
from sklearn.metrics import mean_squared_error
import pickle
import pandas as pd

rental_model = pickle.loads(py_model)

df = rental_score_data

# Get all the columns from the dataframe.
columns = df.columns.tolist()

# variable we will be predicting on.
target = "RentalCount"

# Generate our predictions for the test set.
lin_predictions = rental_model.predict(df[columns])
print(lin_predictions)

# Compute error between our test predictions and the actual values.
lin_mse = mean_squared_error(lin_predictions, df[target])
#print(lin_mse)

predictions_df = pd.DataFrame(lin_predictions)

OutputDataSet = pd.concat([predictions_df, df["RentalCount"], df["Month"], df["Day"], df["WeekDay"], df["Snow"], df["Holiday"], df["Year"]], axis=1)
'
, @input_data_1 = N'Select "RentalCount", "Year" ,"Month", "Day", "WeekDay", "Snow", "Holiday"  from rental_data where Year = 2015'
, @input_data_1_name = N'rental_score_data'
, @params = N'@py_model varbinary(max)'
, @py_model = @py_model
with result sets (("RentalCount_Predicted" float, "RentalCount" float, "Month" float,"Day" float,"WeekDay" float,"Snow" float,"Holiday" float, "Year" float));

END;
GO

-- ################################

DROP TABLE IF EXISTS [dbo].[py_rental_predictions];
GO
--Create a table to store the predictions in
CREATE TABLE [dbo].[py_rental_predictions](
 [RentalCount_Predicted] [int] NULL,
 [RentalCount_Actual] [int] NULL,
 [Month] [int] NULL,
 [Day] [int] NULL,
 [WeekDay] [int] NULL,
 [Snow] [int] NULL,
 [Holiday] [int] NULL,
 [Year] [int] NULL
) ON [PRIMARY]
GO

-- #####################################

TRUNCATE TABLE py_rental_predictions;
--Insert the results of the predictions for test set into a table
INSERT INTO py_rental_predictions
EXEC py_predict_rentalcount 'linear_model';

-- Select contents of the table
SELECT *, RentalCount_Actual-RentalCount_Predicted FROM py_rental_predictions;

-- #####################################


