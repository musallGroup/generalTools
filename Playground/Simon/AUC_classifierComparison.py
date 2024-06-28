# -*- coding: utf-8 -*-
"""
Created on Tue Apr  2 23:32:45 2024

@author: Simon
"""

import pandas as pd
import numpy as np
import statsmodels.formula.api as smf
import statsmodels.api as sm

# Read Data
df = pd.read_csv("https://stats.idre.ucla.edu/stat/data/binary.csv")

# Convert admit column to binary variable
df['admit'] = df['admit'].astype('int')

# Factor Variables
df['rank'] = df['rank'].astype('category')

# Logistic Model
df['rank'] = df['rank'].cat.reorder_categories([4, 1, 2, 3])
mylogistic = smf.glm(formula='admit ~ gre + gpa + rank', data=df, family=sm.families.Binomial()).fit()
print(mylogistic.summary())

# Predict
pred = mylogistic.predict()
finaldata = pd.concat([df, pd.Series(pred, name='pred')], axis=1)

from scipy.stats import mannwhitneyu
def auc_mann_whitney(y, pred):
    y = np.array(y, dtype=bool)
    n1 = np.sum(y)
    n2 = np.sum(~y)
    U, _ = mannwhitneyu(pred[y], pred[~y], alternative='greater')
    return U / (n1 * n2)

# Example usage
auc = auc_mann_whitney(finaldata['admit'], finaldata['pred'])
print(auc)