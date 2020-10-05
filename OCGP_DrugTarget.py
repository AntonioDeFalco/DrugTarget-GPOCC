import numpy as np
import OCGP
from os import listdir
from os.path import isfile, join
from sklearn import metrics
from scipy.io import loadmat
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.model_selection import train_test_split
import threading
from multiprocessing import Process, Pool, Manager

class AsyncFactory:
    def __init__(self, func):#, cb_func):
        self.func = func
        #self.cb_func = cb_func
        self.pool = Pool()
        self.pool = Pool()

    def call(self, *args, **kwargs):
        self.pool.apply_async(self.func, args, kwargs)#, self.cb_func)

    def wait(self):
        self.pool.close()
        self.pool.join()

def processDrug(mypath,kernel):

    data = loadmat(mypath)

    X_train  = data["X_Train"]
    X_test  = data["X_Test"]
    Y_train  = data["Y_Train"]
    Y_test  = data["Y_Test"]

    #minmax_scaler = MinMaxScaler()
    #minmax_scaler.fit(X_train)
    #X_train = minmax_scaler.transform(X_train)
    #X_test = minmax_scaler.transform(X_test)

    ocgp = OCGP.OCGP()

    if kernel == "adaptive":
        p = 30
        ls = ocgp.adaptiveHyper(X_train,p)
        X_train, X_test = ocgp.preprocessing(X_train, X_test, "minmax")
        ocgp.adaptiveKernel(X_train,X_test,p,ls)
    elif kernel == "scaled":
        v = 0.8
        N = 4
        X_train, X_test = ocgp.preprocessing(X_train, X_test, "minmax")
        meanDist_xn, meanDist_yn = ocgp.scaledHyper(X_train, X_test, N)
        ocgp.scaledKernel(X_train, X_test, v, N, meanDist_xn, meanDist_yn)

    scoreTypes = ['mean', 'var', 'pred', 'ratio']
    print(kernel)
    for scoreType in scoreTypes:
        scores = ocgp.getGPRscore(scoreType)
        fpr, tpr, thresholds = metrics.roc_curve(Y_test, scores)
        AUC = metrics.auc(fpr, tpr)
        print(scoreType,":",AUC)

path = './DataDrugTarget/dataset.mat'

kernels = ['adaptive', 'scaled']
scores = ['mean', 'var','pred','ratio']

processDrug(path, 'scaled')

"""
print(kernel)
print(score)
print("datasets processing complete.")
print(AUCmeans)

print("Average")
print(np.mean(AUCmeans))
"""

""" PARALLEL DATASETS
manager = Manager()
AUCmeans = manager.list()
for i in range(numDatasets):
    AUCmeans.append(0.0)


async_UCI = AsyncFactory(processUCI)

for id in range(0,np.size(onlyfiles)):
    async_UCI.call(mypath,id,onlyfiles[id])#,AUCmeans)

async_UCI.wait()
"""


