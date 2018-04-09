function build_checkerboard(mc::AbstractDQMC{CBGeneric})
  const l = mc.l

  l.groups = UnitRange[]
  edges_used = zeros(Int64, l.n_bonds)
  l.checkerboard = zeros(3, l.n_bonds)
  group_start = 1
  group_end = 1

  while minimum(edges_used) == 0
    sites_used = zeros(Int64, l.sites)

    for id in 1:l.n_bonds
      src, trg, typ = l.bonds[id,1:3]

      if edges_used[id] == 1 continue end
      if sites_used[src] == 1 continue end
      if sites_used[trg] == 1 continue end

      edges_used[id] = 1
      sites_used[src] = 1
      sites_used[trg] = 1

      l.checkerboard[:, group_end] = [src, trg, id]
      group_end += 1
    end
    push!(l.groups, group_start:group_end-1)
    group_start = group_end
  end
  l.n_groups = length(l.groups)
end


# helper to cutoff numerical zeros
rem_eff_zeros!(X::AbstractArray) = map!(e->abs.(e)<1e-15?zero(e):e,X,X)

function init_checkerboard_matrices(mc::AbstractDQMC{CBGeneric})
  const l = mc.l
  const p = mc.p
  const H = heltype(mc)

  println("Initializing hopping exponentials (Checkerboard, generic)")

  build_checkerboard(mc)

  const n_groups = l.n_groups
  eT_half = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2) # group, spin (up, down), flavor (x, y)
  eT_half_inv = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)
  eT = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)
  eT_inv = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)

  const VER = [0.0, 1.0]
  const HOR = [1.0, 0.0]

  for f in 1:2
    for s in 1:2
      for (g, gr) in enumerate(l.groups)
        # Build hopping matrix of individual chkr group
        T = zeros(H, l.sites, l.sites)

        for i in gr
          src = l.checkerboard[1,i]
          trg = l.checkerboard[2,i]
          bond = l.checkerboard[3,i]
          v = l.bond_vecs[bond,:]

          if v == VER
            T[trg, src] = T[src, trg] += -l.t[2,f]
          elseif v == HOR
            T[trg, src] = T[src, trg] += -l.t[1,f]
          else
            error("Square lattice??? Check lattice file!", v)
          end
        end

        eT_half[g,s,f] = sparse(rem_eff_zeros!(expm(- 0.5 * p.delta_tau * T)))
        eT_half_inv[g,s,f] = sparse(rem_eff_zeros!(expm(0.5 * p.delta_tau * T)))
        eT[g,s,f] = sparse(rem_eff_zeros!(expm(- p.delta_tau * T)))
        eT_inv[g,s,f] = sparse(rem_eff_zeros!(expm(p.delta_tau * T)))
      end
    end
  end

  if p.opdim == 3
    l.chkr_hop_half = [cat([1,2], eT_half[g,1,1], eT_half[g,2,2], eT_half[g,2,1], eT_half[g,1,2]) for g in 1:n_groups]
    l.chkr_hop_half_inv = [cat([1,2], eT_half_inv[g,1,1], eT_half_inv[g,2,2], eT_half_inv[g,2,1], eT_half_inv[g,1,2]) for g in 1:n_groups]
    l.chkr_hop = [cat([1,2], eT[g,1,1], eT[g,2,2], eT[g,2,1], eT[g,1,2]) for g in 1:n_groups]
    l.chkr_hop_inv = [cat([1,2], eT_inv[g,1,1], eT_inv[g,2,2], eT_inv[g,2,1], eT_inv[g,1,2]) for g in 1:n_groups]

  else # O(2) and O(1) model
    l.chkr_hop_half = [cat([1,2], eT_half[g,1,1], eT_half[g,2,2]) for g in 1:n_groups]
    l.chkr_hop_half_inv = [cat([1,2], eT_half_inv[g,1,1], eT_half_inv[g,2,2]) for g in 1:n_groups]
    l.chkr_hop = [cat([1,2], eT[g,1,1], eT[g,2,2]) for g in 1:n_groups]
    l.chkr_hop_inv = [cat([1,2], eT_inv[g,1,1], eT_inv[g,2,2]) for g in 1:n_groups]
  end
  l.chkr_hop_half_dagger = ctranspose.(l.chkr_hop_half)
  l.chkr_hop_dagger = ctranspose.(l.chkr_hop)

  l.chkr_mu_half = spdiagm(fill(exp(-0.5*p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu_half_inv = spdiagm(fill(exp(0.5*p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu = spdiagm(fill(exp(-p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu_inv = spdiagm(fill(exp(p.delta_tau * -p.mu), p.flv * l.sites))

  hop_mat_exp_chkr = foldl(*,l.chkr_hop_half) * sqrt.(l.chkr_mu)
  r = effreldiff(l.hopping_matrix_exp,hop_mat_exp_chkr)
  r[find(x->x==zero(x),hop_mat_exp_chkr)] = 0.
  println("Checkerboard (generic) - exact (abs):\t\t", maximum(absdiff(l.hopping_matrix_exp,hop_mat_exp_chkr)))
end

#### WITH ARTIFICIAL B-FIELD

function init_checkerboard_matrices_Bfield(mc::AbstractDQMC{CBGeneric})
  const l = mc.l
  const p = mc.p
  const H = heltype(mc)

  println("Initializing hopping exponentials (Bfield, Checkerboard, generic)")

  build_checkerboard(mc)

  const n_groups = l.n_groups
  eT_half = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2) # group, spin (up, down), flavor (x, y)
  eT_half_inv = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)
  eT = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)
  eT_inv = Array{SparseMatrixCSC{H, Int}, 3}(n_groups,2,2)

  B = zeros(2,2) # rowidx = spin up,down, colidx = flavor
  if p.Bfield
    B[1,1] = B[2,2] = 2 * pi / l.sites
    B[1,2] = B[2,1] = - 2 * pi / l.sites
  end

  const VER = [0.0, 1.0]
  const HOR = [1.0, 0.0]

  for f in 1:2
    for s in 1:2
      for (g, gr) in enumerate(l.groups)
        # Build hopping matrix of individual chkr group
        T = zeros(H, l.sites, l.sites)

        for i in gr
          src = l.checkerboard[1,i]
          trg = l.checkerboard[2,i]
          bond = l.checkerboard[3,i]
          v = l.bond_vecs[bond,:]

          if v == VER
            T[trg, src] += - exp(im * l.peirls[s,f][trg,src]) * l.t[2,f]
            T[src, trg] += - exp(im * l.peirls[s,f][src,trg]) * l.t[2,f]
          elseif v == HOR
            T[trg, src] += - exp(im * l.peirls[s,f][trg,src]) * l.t[1,f]
            T[src, trg] += - exp(im * l.peirls[s,f][src,trg]) * l.t[1,f]
          else
            error("Square lattice??? Check lattice file!", v)
          end
        end

        eT_half[g,s,f] = sparse(rem_eff_zeros!(expm(- 0.5 * p.delta_tau * T)))
        eT_half_inv[g,s,f] = sparse(rem_eff_zeros!(expm(0.5 * p.delta_tau * T)))
        eT[g,s,f] = sparse(rem_eff_zeros!(expm(- p.delta_tau * T)))
        eT_inv[g,s,f] = sparse(rem_eff_zeros!(expm(p.delta_tau * T)))
      end
    end
  end

  if p.opdim == 3
    l.chkr_hop_half = [cat([1,2], eT_half[g,1,1], eT_half[g,2,2], eT_half[g,2,1], eT_half[g,1,2]) for g in 1:n_groups]
    l.chkr_hop_half_inv = [cat([1,2], eT_half_inv[g,1,1], eT_half_inv[g,2,2], eT_half_inv[g,2,1], eT_half_inv[g,1,2]) for g in 1:n_groups]
    l.chkr_hop = [cat([1,2], eT[g,1,1], eT[g,2,2], eT[g,2,1], eT[g,1,2]) for g in 1:n_groups]
    l.chkr_hop_inv = [cat([1,2], eT_inv[g,1,1], eT_inv[g,2,2], eT_inv[g,2,1], eT_inv[g,1,2]) for g in 1:n_groups]

  else # O(2) and O(1) model
    l.chkr_hop_half = [cat([1,2], eT_half[g,1,1], eT_half[g,2,2]) for g in 1:n_groups]
    l.chkr_hop_half_inv = [cat([1,2], eT_half_inv[g,1,1], eT_half_inv[g,2,2]) for g in 1:n_groups]
    l.chkr_hop = [cat([1,2], eT[g,1,1], eT[g,2,2]) for g in 1:n_groups]
    l.chkr_hop_inv = [cat([1,2], eT_inv[g,1,1], eT_inv[g,2,2]) for g in 1:n_groups]
  end
  l.chkr_hop_half_dagger = ctranspose.(l.chkr_hop_half)
  l.chkr_hop_dagger = ctranspose.(l.chkr_hop)

  l.chkr_mu_half = spdiagm(fill(exp(-0.5*p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu_half_inv = spdiagm(fill(exp(0.5*p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu = spdiagm(fill(exp(-p.delta_tau * -p.mu), p.flv * l.sites))
  l.chkr_mu_inv = spdiagm(fill(exp(p.delta_tau * -p.mu), p.flv * l.sites))

  hop_mat_exp_chkr = foldl(*,l.chkr_hop_half) * sqrt.(l.chkr_mu)
  r = effreldiff(l.hopping_matrix_exp,hop_mat_exp_chkr)
  r[find(x->x==zero(x),hop_mat_exp_chkr)] = 0.
  println("Checkerboard (Bfield, generic) - exact (abs):\t\t", maximum(absdiff(l.hopping_matrix_exp,hop_mat_exp_chkr)))
end