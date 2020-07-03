#
# Function that generates a new random position for a molecule
#
# the new position is returned in x, a previously allocated array
#
# x_solvent_random might be a view of the array that contains all the solvent
# molecules
#

function random_move!(jfmol :: Int64, jlmol :: Int64, x_solvent :: Array{Float64},
                      irefatom :: Int64, sides :: Vector{Float64}, solute_center :: Vector{Float64}, 
                      ipos :: Int64, lpos :: Int64, x_solvent_random :: Array{Float64}, aux :: MoveAux )

  # To avoid boundary problems, the center of coordinates are generated in a 
  # much larger region, and wrapped aftwerwards
  scale = 100.

  # Generate random coordiantes for the center of mass
  @. aux.newcm = -scale*sides/2 + rand(Float64)*scale*sides + solute_center 

  # Generate random rotation angles 
  @. aux.angles = (2*pi)*rand(Float64)

  # Copy the coordinates of the molecule chosen to the random-coordinates vector
  iatom = ipos - 1
  for i in jfmol:jlmol 
    iatom = iatom + 1
    x_solvent_random[iatom,1] = x_solvent[i,1]
    x_solvent_random[iatom,2] = x_solvent[i,2]
    x_solvent_random[iatom,3] = x_solvent[i,3]
  end
  
  # Take care that this molecule is not split by periodic boundary conditions, by
  # wrapping its coordinates around its reference atom
  @. aux.oldcm = x_solvent[jfmol+irefatom-1,1:3] 
  wrap!(ipos,lpos,x_solvent_random,sides,aux.oldcm)

  # Move molecule to new position
  move!(ipos,lpos,x_solvent_random,aux)

  # Wrap coordinates relative to solute center 
  wrap!(ipos,lpos,x_solvent_random,sides,solute_center)

end

# If the array that will contain the new molecule contains only the new molecule, no need
# to pass ipos and lpos

function random_move!(jfmol :: Int64, jlmol :: Int64, x_solvent :: Array{Float64},
                      irefatom :: Int64, sides :: Vector{Float64}, solute_center :: Vector{Float64}, 
                      x_solvent_random :: Array{Float64}, aux :: MoveAux )
  ipos=1
  lpos=size(x_solvent_random,1)
  random_move!(jfmol,jlmol,x_solvent,irefatom,sides,solute_center,ipos,lpos,x_solvent_random,aux)
end


