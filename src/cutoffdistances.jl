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
                          dc :: CutoffDistances)

  # Reset the dc structure 
  reset!(dc)

  # Loop over solute atoms
  for iat in 1:size(x_solute,2)
    xat = @view(x_solute[1:3,iat])
    # Check the cell of this atom
    i, j, k = icell3D(xat,box)
    # Loop over vicinal cells to compute distances to solvent atoms, and
    # add data to dc structure (includes current cell)
    for ic in i-box.lcell:i+box.lcell
      for jc in j-box.lcell:j+box.lcell
        for kc in k-box.lcell:k+box.lcell
          cutoffdcell!(cutoff,iat,xat,x_solvent,lc_solvent,box,ic,jc,kc,dc)
        end
      end
    end
  end

  return nothing
end
