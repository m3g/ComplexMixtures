#
# returns the index of the linked cell, in the 1D representation, from its i,j,k coordinates
#

icell1D(nc :: T, i :: Int64, j :: Int64, k :: Int64) where T <: Vi3 = (i-1)*nc[2]*nc[3] + (j-1)*nc[3] + k
