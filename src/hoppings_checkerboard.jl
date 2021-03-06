"""
Checkerboard initialization: Assaad four site version for square lattice
"""
function find_four_site_hopping_corners(l::Lattice)
  pc = Int(floor(l.sites/4))

  A_corners = zeros(Int, pc)
  idx = 1
  tolinidx = reshape(collect(1:l.sites),l.L,l.L)
  for x in 1:2:l.L
      for y in 1:2:l.L
          A_corners[idx] = tolinidx[y,x]
          idx += 1
      end
  end
  B_corners = l.neighbors[1,l.neighbors[2,A_corners]]
  return A_corners, B_corners
end

function build_four_site_hopping_matrix_exp(mc::AbstractDQMC{CBAssaad}, corners::Tuple{Array{Int64,1},Array{Int64,1}}, prefac::Float64=0.5)
  p = mc.p
  l = mc.l

  pc = Int(floor(l.sites/4))
  chkr_hop_4site = Array{SparseMatrixCSC, 3}(undef,pc,2,2) # i, group (A, B), hopping flavor (tx, ty)
  chkr_hop_4site_inv = Array{SparseMatrixCSC, 3}(undef,pc,2,2)

  # build explicitly based on analytic form (only without mag field)
  for tflv in 1:2
    for g in 1:2
      for c in 1:pc

        chkr_hop_4site[c,g,tflv] = sparse(1.0I, l.sites, l.sites)
        chkr_hop_4site_inv[c,g,tflv] = sparse(1.0I, l.sites, l.sites)

        # Tijmn where i ist bottom left and i<j<m<n.
        i = corners[g][c]
        j = l.neighbors[1,i]
        m = l.neighbors[2,i]
        n = l.neighbors[2,j]

        inds = sort!([corners[g][c], l.neighbors[1,i], l.neighbors[2,i], l.neighbors[2,j]])

        th = l.t[1,tflv]
        tv = l.t[2,tflv]
        fac = -prefac * p.delta_tau

        chkr_hop_4site[c,g,tflv][i,i] = chkr_hop_4site[c,g,tflv][j,j] = chkr_hop_4site[c,g,tflv][m,m] = chkr_hop_4site[c,g,tflv][n,n] = cosh(fac * -th) * cosh(fac * -tv) #
        chkr_hop_4site[c,g,tflv][i,n] = chkr_hop_4site[c,g,tflv][j,m] = chkr_hop_4site[c,g,tflv][m,j] = chkr_hop_4site[c,g,tflv][n,i] = sinh(fac * -th) * sinh(fac * -tv)
        chkr_hop_4site[c,g,tflv][i,j] = chkr_hop_4site[c,g,tflv][j,i] = chkr_hop_4site[c,g,tflv][m,n] = chkr_hop_4site[c,g,tflv][n,m] = cosh(fac * -th) * sinh(fac * -tv) #
        chkr_hop_4site[c,g,tflv][i,m] = chkr_hop_4site[c,g,tflv][j,n] = chkr_hop_4site[c,g,tflv][m,i] = chkr_hop_4site[c,g,tflv][n,j] = sinh(fac * -th) * cosh(fac * -tv)

        chkr_hop_4site_inv[c,g,tflv][i,i] = chkr_hop_4site_inv[c,g,tflv][j,j] = chkr_hop_4site_inv[c,g,tflv][m,m] = chkr_hop_4site_inv[c,g,tflv][n,n] = cosh(-fac * -th) * cosh(-fac * -tv)
        chkr_hop_4site_inv[c,g,tflv][i,n] = chkr_hop_4site_inv[c,g,tflv][j,m] = chkr_hop_4site_inv[c,g,tflv][m,j] = chkr_hop_4site_inv[c,g,tflv][n,i] = sinh(-fac * -th) * sinh(-fac * -tv)
        chkr_hop_4site_inv[c,g,tflv][i,j] = chkr_hop_4site_inv[c,g,tflv][j,i] = chkr_hop_4site_inv[c,g,tflv][m,n] = chkr_hop_4site_inv[c,g,tflv][n,m] = cosh(-fac * -th) * sinh(-fac * -tv)
        chkr_hop_4site_inv[c,g,tflv][i,m] = chkr_hop_4site_inv[c,g,tflv][j,n] = chkr_hop_4site_inv[c,g,tflv][m,i] = chkr_hop_4site_inv[c,g,tflv][n,j] = sinh(-fac * -th) * cosh(-fac * -tv)

      end
    end
  end

  return chkr_hop_4site, chkr_hop_4site_inv
end

function init_checkerboard_matrices(mc::AbstractDQMC{CBAssaad})
  p = mc.p
  l = mc.l

  println("Initializing hopping exponentials (Checkerboard)")
  pc = Int(floor(l.sites/4))

  corners = find_four_site_hopping_corners(l)

  chkr_hop_4site_half, chkr_hop_4site_half_inv = build_four_site_hopping_matrix_exp(mc, corners, 0.5)
  chkr_hop_4site, chkr_hop_4site_inv = build_four_site_hopping_matrix_exp(mc, corners, 1.)

  eTx_A_half = foldl(*,chkr_hop_4site_half[:,1,1])
  eTx_B_half = foldl(*,chkr_hop_4site_half[:,2,1])
  eTy_A_half = foldl(*,chkr_hop_4site_half[:,1,2])
  eTy_B_half = foldl(*,chkr_hop_4site_half[:,2,2])
  eTx_A = foldl(*,chkr_hop_4site[:,1,1])
  eTx_B = foldl(*,chkr_hop_4site[:,2,1])
  eTy_A = foldl(*,chkr_hop_4site[:,1,2])
  eTy_B = foldl(*,chkr_hop_4site[:,2,2])

  eTx_A_half_inv = foldl(*,chkr_hop_4site_half_inv[:,1,1])
  eTx_B_half_inv = foldl(*,chkr_hop_4site_half_inv[:,2,1])
  eTy_A_half_inv = foldl(*,chkr_hop_4site_half_inv[:,1,2])
  eTy_B_half_inv = foldl(*,chkr_hop_4site_half_inv[:,2,2])
  eTx_A_inv = foldl(*,chkr_hop_4site_inv[:,1,1])
  eTx_B_inv = foldl(*,chkr_hop_4site_inv[:,2,1])
  eTy_A_inv = foldl(*,chkr_hop_4site_inv[:,1,2])
  eTy_B_inv = foldl(*,chkr_hop_4site_inv[:,2,2])

  if p.opdim == 3
    eT_A_half = cat(eTx_A_half,eTy_A_half,eTx_A_half,eTy_A_half, dims=(1,2))
    eT_B_half = cat(eTx_B_half,eTy_B_half,eTx_B_half,eTy_B_half, dims=(1,2))
    eT_A_half_inv = cat(eTx_A_half_inv,eTy_A_half_inv,eTx_A_half_inv,eTy_A_half_inv, dims=(1,2))
    eT_B_half_inv = cat(eTx_B_half_inv,eTy_B_half_inv,eTx_B_half_inv,eTy_B_half_inv, dims=(1,2))
    eT_A = cat(eTx_A,eTy_A,eTx_A,eTy_A, dims=(1,2))
    eT_B = cat(eTx_B,eTy_B,eTx_B,eTy_B, dims=(1,2))
    eT_A_inv = cat(eTx_A_inv,eTy_A_inv,eTx_A_inv,eTy_A_inv, dims=(1,2))
    eT_B_inv = cat(eTx_B_inv,eTy_B_inv,eTx_B_inv,eTy_B_inv, dims=(1,2))
  else
    eT_A_half = cat(eTx_A_half,eTy_A_half, dims=(1,2))
    eT_B_half = cat(eTx_B_half,eTy_B_half, dims=(1,2))
    eT_A_half_inv = cat(eTx_A_half_inv,eTy_A_half_inv, dims=(1,2))
    eT_B_half_inv = cat(eTx_B_half_inv,eTy_B_half_inv, dims=(1,2))
    eT_A = cat(eTx_A,eTy_A, dims=(1,2))
    eT_B = cat(eTx_B,eTy_B, dims=(1,2))
    eT_A_inv = cat(eTx_A_inv,eTy_A_inv, dims=(1,2))
    eT_B_inv = cat(eTx_B_inv,eTy_B_inv, dims=(1,2))
  end

  l.chkr_hop_half = [eT_A_half, eT_B_half]
  l.chkr_hop_half_inv = [eT_A_half_inv, eT_B_half_inv]
  l.chkr_hop_half_dagger = [adjoint(eT_A_half), adjoint(eT_B_half)]
  l.chkr_hop = [eT_A, eT_B]
  l.chkr_hop_inv = [eT_A_inv, eT_B_inv]
  l.chkr_hop_dagger = [adjoint(eT_A), adjoint(eT_B)]

  muv = vcat(fill(p.mu1,l.sites),fill(p.mu2,l.sites))
  muv = repeat(muv, outer=[Int(p.flv/2)])
  l.chkr_mu_half = sparse(Diagonal(exp.(-0.5*p.delta_tau * -muv)))
  l.chkr_mu_half_inv = sparse(Diagonal(exp.(0.5*p.delta_tau * -muv)))
  l.chkr_mu = sparse(Diagonal(exp.(-p.delta_tau * -muv)))
  l.chkr_mu_inv = sparse(Diagonal(exp.(p.delta_tau * -muv)))

  l.n_groups = 2

  hop_mat_exp_chkr = l.chkr_hop_half[1] * l.chkr_hop_half[2] * sqrt.(l.chkr_mu)
  r = effreldiff(l.hopping_matrix_exp,hop_mat_exp_chkr)
  r[findall(x->x==zero(x), hop_mat_exp_chkr)] .= 0
  println("Checkerboard - exact (abs):\t\t", maximum(absdiff(l.hopping_matrix_exp,hop_mat_exp_chkr)))
  # println("Checkerboard - exact (eff rel):\t\t", maximum(r))
end


#### WITH ARTIFICIAL B-FIELD

function build_four_site_hopping_matrix_Bfield(mc::AbstractDQMC{CBAssaad}, corner::Int,f::Int,s::Int)
  l = mc.l
  H = heltype(mc)

  sites_clockwise = [corner, l.neighbors[1,corner], l.neighbors[1,l.neighbors[2,corner]], l.neighbors[2,corner]]
  shift_sites_clockwise = circshift(sites_clockwise,-1)

  h = l.t[1,f]
  v = l.t[2,f]

  hop = -1 * repeat(H[v, h, v, h], outer=2)

  @inbounds for k in 1:4
    i = sites_clockwise[k]
    j = shift_sites_clockwise[k]

    hop[k] *= exp(im * l.peirls[s,f][i,j]) # i,j = trg,src
    hop[k+4] *= exp(im * l.peirls[s,f][j,i]) # j,i = trg,src
  end

  # return T only filled with T_ijkl hoppings
  return sparse([sites_clockwise; shift_sites_clockwise],[shift_sites_clockwise; sites_clockwise],hop,l.sites,l.sites)
end

function build_four_site_hopping_matrix_exp_Bfield(mc::AbstractDQMC{CBAssaad}, corners::Tuple{Array{Int64,1},Array{Int64,1}}, prefac::Float64=0.5)
  p = mc.p
  l = mc.l
  H = heltype(mc)

  B = zeros(2,2) # rowidx = spin up,down, colidx = flavor
  if p.Bfield
    B[1,1] = B[2,2] = 2 * pi / l.sites
    B[1,2] = B[2,1] = - 2 * pi / l.sites
  end

  pc = Int(floor(l.sites/4))

  chkr_hop_4site = Array{SparseMatrixCSC{H, Int}, 4}(undef, pc,2,2,2) # i, group (A, B), spin (up, down), flavor (x, y)
  chkr_hop_4site_inv = Array{SparseMatrixCSC{H, Int}, 4}(undef, pc,2,2,2)

  # build numerically (due to mag field)
  for f in 1:2
    for s in 1:2
      for g in 1:2
        for c in 1:pc

          fac = -prefac * p.delta_tau
          
          chkr_hop_4site[c,g,s,f] = sparse(rem_eff_zeros!(exp(fac * Matrix(build_four_site_hopping_matrix_Bfield(mc,corners[g][c],f,s)))))
          chkr_hop_4site_inv[c,g,s,f] = sparse(rem_eff_zeros!(exp(-fac * Matrix(build_four_site_hopping_matrix_Bfield(mc,corners[g][c],f,s)))))

        end
      end
    end
  end

  return chkr_hop_4site, chkr_hop_4site_inv
end

function init_checkerboard_matrices_Bfield(mc::AbstractDQMC{CBAssaad})
  p = mc.p
  l = mc.l
  H = heltype(mc)

  println("Initializing hopping exponentials (Bfield, Checkerboard)")
  # pc = Int(floor(l.sites/4))

  corners = find_four_site_hopping_corners(l)

  chkr_hop_4site_half, chkr_hop_4site_half_inv = build_four_site_hopping_matrix_exp_Bfield(mc, corners, 0.5)
  chkr_hop_4site, chkr_hop_4site_inv = build_four_site_hopping_matrix_exp_Bfield(mc, corners, 1.)

  eT_half = Array{SparseMatrixCSC{H, Int}, 3}(undef,2,2,2) # group (A, B), spin (up, down), flavor (x, y)
  eT_half_inv = Array{SparseMatrixCSC{H, Int}, 3}(undef,2,2,2)
  eT = Array{SparseMatrixCSC{H, Int}, 3}(undef,2,2,2)
  eT_inv = Array{SparseMatrixCSC{H, Int}, 3}(undef,2,2,2)

  for g in 1:2
    for f in 1:2
      for s in 1:2
        eT_half[g,s,f] = foldl(*,chkr_hop_4site_half[:,g,s,f])
        eT_half_inv[g,s,f] = foldl(*,chkr_hop_4site_half_inv[:,g,s,f])
        eT[g,s,f] = foldl(*,chkr_hop_4site[:,g,s,f])
        eT_inv[g,s,f] = foldl(*,chkr_hop_4site_inv[:,g,s,f])
      end
    end
  end

  if p.opdim == 3
    eT_A_half = cat(eT_half[1,1,1], eT_half[1,2,2], eT_half[1,2,1], eT_half[1,1,2], dims=(1,2))
    eT_B_half = cat(eT_half[2,1,1], eT_half[2,2,2], eT_half[2,2,1], eT_half[2,1,2], dims=(1,2))
    eT_A_half_inv = cat(eT_half_inv[1,1,1], eT_half_inv[1,2,2], eT_half_inv[1,2,1], eT_half_inv[1,1,2], dims=(1,2))
    eT_B_half_inv = cat(eT_half_inv[2,1,1], eT_half_inv[2,2,2], eT_half_inv[2,2,1], eT_half_inv[2,1,2], dims=(1,2))
    eT_A = cat(eT[1,1,1], eT[1,2,2], eT[1,2,1], eT[1,1,2], dims=(1,2))
    eT_B = cat(eT[2,1,1], eT[2,2,2], eT[2,2,1], eT[2,1,2], dims=(1,2))
    eT_A_inv = cat(eT_inv[1,1,1], eT_inv[1,2,2], eT_inv[1,2,1], eT_inv[1,1,2], dims=(1,2))
    eT_B_inv = cat(eT_inv[2,1,1], eT_inv[2,2,2], eT_inv[2,2,1], eT_inv[2,1,2], dims=(1,2)) 
  else # O(2) and O(1) model
    eT_A_half = cat(eT_half[1,1,1], eT_half[1,2,2], dims=(1,2))
    eT_B_half = cat(eT_half[2,1,1], eT_half[2,2,2], dims=(1,2))
    eT_A_half_inv = cat(eT_half_inv[1,1,1], eT_half_inv[1,2,2], dims=(1,2))
    eT_B_half_inv = cat(eT_half_inv[2,1,1], eT_half_inv[2,2,2], dims=(1,2))
    eT_A = cat(eT[1,1,1], eT[1,2,2], dims=(1,2))
    eT_B = cat(eT[2,1,1], eT[2,2,2], dims=(1,2))
    eT_A_inv = cat(eT_inv[1,1,1], eT_inv[1,2,2], dims=(1,2))
    eT_B_inv = cat(eT_inv[2,1,1], eT_inv[2,2,2], dims=(1,2))
  end

  l.chkr_hop_half = [eT_A_half, eT_B_half]
  l.chkr_hop_half_inv = [eT_A_half_inv, eT_B_half_inv]
  l.chkr_hop_half_dagger = [adjoint(eT_A_half), adjoint(eT_B_half)]
  l.chkr_hop = [eT_A, eT_B]
  l.chkr_hop_inv = [eT_A_inv, eT_B_inv]
  l.chkr_hop_dagger = [adjoint(eT_A), adjoint(eT_B)]

  muv = vcat(fill(p.mu1,l.sites),fill(p.mu2,l.sites))
  muv = repeat(muv, outer=[Int(p.flv/2)])
  l.chkr_mu_half = sparse(Diagonal(exp.(-0.5*p.delta_tau * -muv)))
  l.chkr_mu_half_inv = sparse(Diagonal(exp.(0.5*p.delta_tau * -muv)))
  l.chkr_mu = sparse(Diagonal(exp.(-p.delta_tau * -muv)))
  l.chkr_mu_inv = sparse(Diagonal(exp.(p.delta_tau * -muv)))

  l.n_groups = 2

  hop_mat_exp_chkr = l.chkr_hop_half[1] * l.chkr_hop_half[2] * sqrt.(l.chkr_mu)
  r = effreldiff(l.hopping_matrix_exp,hop_mat_exp_chkr)
  r[findall(x -> x == zero(x), hop_mat_exp_chkr)] .= 0
  println("Checkerboard (Bfield) - exact (abs):\t\t", maximum(absdiff(l.hopping_matrix_exp,hop_mat_exp_chkr)))
  # println("Checkerboard (Bfield) - exact (eff rel):\t\t", maximum(r))
end