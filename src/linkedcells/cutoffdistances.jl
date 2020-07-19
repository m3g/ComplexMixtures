#
# cutoffdistances: This routine that returns a list of the distances 
#                  between atoms that are smaller than a specified cutoff,
#                  for a given set of coordinates.
#
# L. Martinez, Sep 23, 2014. (to Julia on June, 2020)
#
# Returns nd, the number of distances smaller than the cutoff, and modifies dc
#

function cutoffdistances!(cutoff :: Float64,
                          x_solute :: AbstractArray{Float64},
                          x_solvent :: AbstractArray{Float64},
                          lc_solvent :: LinkedCells,
                          box :: Box, 
                          dc :: Union{CutoffDistances,Vector{CutoffDistances}})

  # Reset the dc structure 
  reset!(dc)

  nat = size(x_solute,1)
  n_cells_each_dim = 2*box.lcell+1
  ncells = n_cells_each_dim^3 
  noperations = nat*ncells
  Threads.@threads for iop in 1:noperations
    ithread = Threads.threadid()

    iat = trunc(Int64,(iop-1)/ncells)+1
    xat = @view(x_solute[iat,1:3])
    i, j, k = icell3D(xat,box)

    icell = iop - (iat-1)*ncells
    ic, jc, kc = icell3D(n_cells_each_dim,icell)

    ic = ic - (box.lcell + 1) + i
    jc = jc - (box.lcell + 1) + j
    kc = kc - (box.lcell + 1) + k

    cutoffdcell!(cutoff,iat,xat,x_solvent,lc_solvent,box,ic,jc,kc,dc[ithread])

  end

  # Reduce the data from the parallel computation
  reduce!(dc)

end
