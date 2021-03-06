macro ResultFields_Start()
  ex = quote
    nbins::Int 
    dbulk::Float64
    cutoff::Float64
    d::Vector{Float64} = zeros(nbins)

    # Data to compute the MDDF distribution and corresponding KB integral
    md_count::Vector{Float64} = zeros(nbins)
    md_count_random::Vector{Float64} = zeros(nbins)
    sum_md_count::Vector{Float64} = zeros(nbins)
    sum_md_count_random::Vector{Float64} = zeros(nbins)
    mddf::Vector{Float64} = zeros(nbins)
    kb::Vector{Float64} = zeros(nbins)

    # Properties of the solute and solvent selections
    autocorrelation::Bool
    solvent::SolSummary
    solute::SolSummary
   end
   esc(ex)
end

macro ResultFields_AtomsMatrix()
  ex = quote
    # Atomic contributions to the MDDFs
    solute_atom::Array{Float64,2} = zeros(nbins,solute.natomspermol)
    solvent_atom::Array{Float64,2} = zeros(nbins,solvent.natomspermol)
  end
  esc(ex)
end

macro ResultFields_AtomsVector()
  ex = quote
    # Atomic contributions to the MDDFs
    solute_atom::Array{Float64} = zeros(nbins,solute.natomspermol)
    solvent_atom::Array{Float64} = zeros(nbins,solvent.natomspermol)
  end
  esc(ex)
end
    
macro ResultFields_End()
  ex = quote
    # Data to compute a RDF and the KB integral from this count
    rdf_count::Vector{Float64} = zeros(nbins)
    rdf_count_random::Vector{Float64} = zeros(nbins)
    sum_rdf_count::Vector{Float64} = zeros(nbins)
    sum_rdf_count_random::Vector{Float64} = zeros(nbins)
    rdf::Vector{Float64} = zeros(nbins)
    kb_rdf::Vector{Float64} = zeros(nbins)

    # Overall densities and volumes
    density::Density = Density()
    volume::Volume = Volume(nbins)

    # Options of the calculation
    options::Options
    irefatom::Int
    lastframe_read::Int
    nframes_read::Int

    # File name(s) of the trajectories in this results 
    files::Vector{String}
    weights::Vector{Float64} 
  end
  esc(ex)
end

"""

$(TYPEDEF)

Structure to contain the results of the MDDF calculation.

$(TYPEDFIELDS)


"""
@with_kw_noshow struct Result
  @ResultFields_Start()
  @ResultFields_AtomsMatrix()
  @ResultFields_End()
end

# The mutable version is used for reading saved data, because some vectors
# need to be reshaped
@with_kw_noshow mutable struct MutableResult
  @ResultFields_Start()
  @ResultFields_AtomsVector()
  @ResultFields_End()
end

#
# Initialize the data structure that is returned from the computation, and checks some
# input parameters for consistency
#

function Result(trajectory::Trajectory, options::Options; irefatom = -1) 

  # Check for simple input errors
  if options.stride < 1
    error("in MDDF options: stride cannot be less than 1. ")
  end
  if options.lastframe > 0 && options.lastframe < options.firstframe
    error("in MDDF options: lastframe must be greater or equal to firstframe. ")
  end
  if options.lastframe > trajectory.nframes
    error("in MDDF options: lastframe is greater than trajectory.nframes. ")
  end

  # Check for problems in dbulk and cutoff definitions
  cutoff = options.dbulk
  if (options.dbulk/options.binstep)%1 > 1.e-5
    error("in MDDF options: dbulk must be a multiple of binstep.")
  end
  if options.usecutoff
    if options.dbulk >= options.cutoff 
      error(" in MDDF options: The bulk volume is zero (dbulk must be smaller than cutoff). ")
    end
    if (options.cutoff/options.binstep)%1 > 1.e-5
      error("in MDDF options: cutoff must be a multiple of binstep.")
    end
    if ((options.cutoff-options.dbulk)/options.binstep)%1 > 1.e-5
      error("in MDDF options: (cutoff-dbulk) must be a multiple of binstep. ")
    end
    cutoff = options.cutoff
  end
  nbins = setbin(cutoff,options.binstep)-1

  if options.irefatom > trajectory.solvent.natoms 
    error("in MDDF options: Reference atom index", options.irefatom, " is greater than number of "*
          "                 atoms of the solvent molecule. ")
  end

  # Set reference atom as the closest one to the center of coordinates of the molecule, as default
  if irefatom == -1
    if options.irefatom == -1
      nextframe!(trajectory)
      xfirst = trajectory.x_solvent[1:trajectory.solvent.natomspermol]
      cm = centerofcoordinates(xfirst)
      dmin, one, irefatom = minimumdistance(cm,xfirst)
      firstframe(trajectory)
    else
      irefatom = options.irefatom
    end
  end

  # Last frame to be considered
  if options.lastframe == -1
    lastframe_read = trajectory.nframes
  else
    lastframe_read = options.lastframe
  end
 
  # Actual number of frames that are read considering lastframe and stride
  nframes_read = round(Int,(lastframe_read - options.firstframe + 1)/options.stride)
  if nframes_read == 0
    error("Number of frames to read is zero. Check input parameters.")
  end

  # Return data structure built up

  return Result(options=options,
                nbins=nbins,
                dbulk=options.dbulk,
                cutoff=cutoff,
                irefatom=irefatom,
                lastframe_read=lastframe_read,
                nframes_read=nframes_read,
                autocorrelation=isautocorrelation(trajectory),
                solute=SolSummary(trajectory.solute),
                solvent=SolSummary(trajectory.solvent),
                files=[trajectory.filename],weights=[1.0])

end

#
# What to show at the REPL
#

Base.show(io::IO, R::Result ) = Base.show(overview(R))

