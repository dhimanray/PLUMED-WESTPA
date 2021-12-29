import numpy as np

l = np.loadtxt('COLVAR')

print("{:.4f}".format(l[1]*10.0)) #convert to A from ps
