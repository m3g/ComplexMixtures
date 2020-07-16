#
# mddf_naive
#
# Computes the MDDF using the naive algorithm consisting of computing all distances
# useful for development purposes
#
# http://m3g.iqm.unicamp.br/
# http://github.com/m3g/MDDF
#  

function mddf_naive_self(trajectory, options :: Options)  

  # Simplify code by assigning some shortened names
  solvent = trajectory.solvent
  x_solvent = trajectory.x_solvent
  
  # The number of random samples for numerical normalization
  nsamples = options.n_random_samples

  # Initializing the structure that carries all resuts
  R = Result(trajectory,options)

  # Vector to annotate the molecules that belong to the bulk solution
  jmol_in_bulk = Vector{Int64}(undef,solvent.nmols)

  # Vector that will contain randomly generated solvent molecules
  x_solvent_random = Array{Float64}(undef,solvent.natomspermol,3)

  # Auxiliary structure to random generation of solvent coordiantes
  moveaux = MoveAux(solvent.natomspermol)

  # Auxiliar vector to contain the center of coordinates of a solute
  solute_center = zeros(3)
  
  # Counter for the total number of bulk molecules
  nbulk = 0

  # Structure to organize counters for each frame only
  volume_frame = Volume(R.nbins)
  rdf_count_random_frame = zeros(R.nbins)

  # Number of pairs of molecules (the number of distances computed)
  npairs = round(Int64,solvent.nmols*(solvent.nmols-1)/2)

  # Computing all minimum-distances
  progress = Progress(R.nframes_read*solvent.nmols,1)
  for iframe in 1:R.lastframe_read

    # Reset counters for this frame
    reset!(volume_frame)
    @. rdf_count_random_frame = 0.

    # reading coordinates of next frame
    nextframe!(trajectory)
    if iframe < options.firstframe 
      continue
    end
    if iframe%options.stride != 0
      continue
    end

    # get pbc sides in this frame
    sides = getsides(trajectory,iframe)

    volume_frame.total = sides[1]*sides[2]*sides[3]
    R.volume.total = R.volume.total + volume_frame.total
   
    R.density.solvent = R.density.solvent + (solvent.nmols / volume_frame.total)
    R.density.solute = R.density.solvent

    # Check if the cutoff is not too large considering the periodic cell size
    if options.cutoff > sides[1]/2. || options.cutoff > sides[2]/2. || options.cutoff > sides[3]/2.
      error("in MDDF: cutoff or dbulk > periodic_dimension/2 ")
    end

    # Counter for the cumulative number of solvent molecules found to be in bulk
    # relative to each solute molecule
    n_solvent_in_bulk = 0

    # computing the minimum distances, cycle over solute molecules
    for imol in 1:solvent.nmols-1
      next!(progress)

      # first and last atoms of the current solute molecule
      x_this_solute = viewmol(imol,x_solvent,solvent)

      # Wrap all molecules relative to the reference atom of this solute molecule 
      # (solute and solvent are the same here, so everything is wrapped)
      wrap!(x_solvent,sides,@view(x_this_solute[R.irefatom,1:3]))
      solute_center = @view(x_this_solute[R.irefatom,1:3])

      # counter for the number of solvent molecules in bulk for this solute molecule
      n_jmol_in_bulk = 0

      #
      # cycle over solvent molecules to compute the MDDF count
      #
      for jmol in imol+1:solvent.nmols

        # first and last atoms of this solvent molecule
        x_this_solvent = viewmol(jmol,x_solvent,solvent)

        # Compute minimum distance 
        dmin, iatom, jatom, drefatom = minimumdistance(x_this_solute,x_this_solvent,R.irefatom)

        # Update histogram for computation of MDDF
        if dmin <= options.dbulk
          ibin = setbin(dmin,options.binstep)
          R.md_count[ibin] += 1
          R.solute_atom[ibin,iatom] += 1 
          R.solvent_atom[ibin,jatom] += 1 
        else
          n_jmol_in_bulk += 1
          jmol_in_bulk[n_jmol_in_bulk] = jmol
        end

        # Update histogram for the computation of the RDF
        if drefatom <= options.dbulk
          ibin = setbin(drefatom,options.binstep) 
          R.rdf_count[ibin] += 1
        end

      end # solvent molecules 

      # Sum up the number of solvent molecules found in bulk for this solute to the total 
      n_solvent_in_bulk = n_solvent_in_bulk + n_jmol_in_bulk

      #
      # Computing the random-solvent distribution to compute the random minimum-distance count
      # Since this is a self-distribution, bulk or non-bulk molecules have identical shapes
      # 
      for i in 1:options.n_random_samples
        # Choose randomly one molecule
        if n_jmol_in_bulk > 0
          jmol = jmol_in_bulk[rand(1:n_jmol_in_bulk)]
        else
          jmol = rand(1:solvent.nmols)
        end
        # Generate new random coordinates (translation and rotation) for this molecule
        x_this_solvent = viewmol(jmol,x_solvent,solvent)
        random_move!(x_this_solvent,R.irefatom,sides,x_solvent_random,moveaux)
        wrap!(x_solvent_random,sides,solute_center)
        dmin, iatom, jatom, drefatom = minimumdistance(x_this_solute,
                                                       x_solvent_random,
                                                       R.irefatom)
        if dmin <= options.dbulk
          ibin = setbin(dmin,options.binstep)
          R.md_count_random[ibin] += 1
        end
        # Use the position of the reference atom to compute the shell volume by Monte-Carlo integration
        if drefatom <= options.dbulk
          ibin = setbin(drefatom,options.binstep)
          rdf_count_random_frame[ibin] += 1
        end
      end # random solvent sampling

    end # solute molecules

    # Update global counters with the data of this frame
    update_counters_frame!(R,rdf_count_random_frame,volume_frame,solvent,
                           nsamples,npairs,n_solvent_in_bulk)

  end # frames
  closetraj(trajectory)

  # Setup the final data structure with final values averaged over the number of frames,
  # sampling, etc, and computes final distributions and integrals
  nfix = solvent.nmols^2/npairs
  s = Samples(R.nframes_read*(trajectory.solvent.nmols-1),
              R.nframes_read*options.n_random_samples*nfix)
  finalresults!(R,options,trajectory,s)

  return R

end

