# -------------------------------------------------------
#                        Generic
# -------------------------------------------------------
function slice_matrix(mc::AbstractDQMC, slice::Int, power::Float64=1.)
  a = mc.a

  res = Matrix{geltype(mc)}(I, mc.p.flv*mc.l.sites, mc.p.flv*mc.l.sites)

  @mytimeit a.to "slice_matrix" begin
  if power > 0
    multiply_B_left!(mc, slice, res)
  else
    multiply_B_inv_left!(mc, slice, res)
  end
  end
  return res
end



# -------------------------------------------------------
#  				No checkerboard
# -------------------------------------------------------
# Beff(slice) = exp(−1/2∆τT)exp(−1/2∆τT)exp(−∆τV(slice))
function slice_matrix!(mc::DQMC_CBFalse, slice::Int, power::Float64=1., Bl::AbstractMatrix=mc.s.Bl)
  eT = mc.l.hopping_matrix_exp
  eTinv = mc.l.hopping_matrix_exp_inv
  eV = mc.s.eV
  tmp = mc.g.tmp

  interaction_matrix_exp!(mc, slice, power, eV)
  
  if power > 0
    mul!(tmp, eT, eV)
    mul!(Bl, eT, tmp)
    # return eT * eT * eV
  else
    mul!(tmp, eTinv, eTinv)
    mul!(Bl, eV, tmp)
    # return eV * eTinv * eTinv
  end
  nothing # slice_matrix now in Bl
end

function multiply_B_left!(mc::DQMC_CBFalse, slice::Int, M::AbstractMatrix)
  @mytimeit mc.a.to "multiply_B (combined)" begin
  @mytimeit mc.a.to "multiply_B_left!" begin
  slice_matrix!(mc, slice, 1., mc.s.Bl)
  mul!(mc.g.tmp, mc.s.Bl, M)
  M .= mc.g.tmp
  end #timeit
  end #timeit
  nothing
end
function multiply_B_right!(mc::DQMC_CBFalse, slice::Int, M::AbstractMatrix)
  @mytimeit mc.a.to "multiply_B (combined)" begin
  @mytimeit mc.a.to "multiply_B_right!" begin
  slice_matrix!(mc, slice, 1., mc.s.Bl)
  mul!(mc.g.tmp, M, mc.s.Bl)
  M .= mc.g.tmp
	end #timeit
  end #timeit
  nothing
end
function multiply_B_inv_right!(mc::DQMC_CBFalse, slice::Int, M::AbstractMatrix)
  @mytimeit mc.a.to "multiply_B (combined)" begin
  @mytimeit mc.a.to "multiply_B_inv_right!" begin
  slice_matrix!(mc, slice, -1., mc.s.Bl)
  mul!(mc.g.tmp, M, mc.s.Bl)
  M .= mc.g.tmp
	end #timeit
  end #timeit
  nothing
end
function multiply_B_inv_left!(mc::DQMC_CBFalse, slice::Int, M::AbstractMatrix)
  @mytimeit mc.a.to "multiply_B (combined)" begin
  @mytimeit mc.a.to "multiply_B_inv_left!" begin
  slice_matrix!(mc, slice, -1., mc.s.Bl)
  mul!(mc.g.tmp, mc.s.Bl, M)
  M .= mc.g.tmp
	end #timeit
  end #timeit
  nothing
end
function multiply_daggered_B_left!(mc::DQMC_CBFalse, slice::Int, M::AbstractMatrix)
  @mytimeit mc.a.to "multiply_B (combined)" begin
  @mytimeit mc.a.to "multiply_daggered_B_left!" begin
  slice_matrix!(mc, slice, 1., mc.s.Bl)
  mul!(mc.g.tmp, adjoint(mc.s.Bl), M) # ctranspose
  M .= mc.g.tmp
  end #timeit
  end #timeit
  nothing
end



# -------------------------------------------------------
#  				Assaad checkerboard
# -------------------------------------------------------
function multiply_B_left!(mc::AbstractDQMC{CBAssaad}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_left!" begin

  @mytimeit a.to "Bleft_construct_eV" begin
  interaction_matrix_exp!(mc,slice,1.,s.eV)
  end
  @mytimeit a.to "Bleft_mult_eV" begin
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  end
  mul!(g.tmp, l.chkr_mu, M)
  M .= g.tmp

  @mytimeit a.to "Bleft_mult_eT" begin
  mul!(g.tmp, l.chkr_hop_half[2], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop[1], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop_half[2], M)
  M .= g.tmp
  end
  end
  end #timeit
  nothing
end

function multiply_B_right!(mc::AbstractDQMC{CBAssaad}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_right!" begin

  interaction_matrix_exp!(mc,slice,1.,s.eV)
  mul!(g.tmp, M, l.chkr_hop_half[2])
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_hop[1])
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_hop_half[2])
  M .= g.tmp

  mul!(g.tmp, M, l.chkr_mu)
  M .= g.tmp
  mul!(g.tmp, M, s.eV)
  M .= g.tmp
  end
  end #timeit
  nothing
end

function multiply_B_inv_left!(mc::AbstractDQMC{CBAssaad}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_inv_left!" begin
  
  interaction_matrix_exp!(mc, slice, -1., s.eV)
  mul!(g.tmp, l.chkr_hop_half_inv[2], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop_inv[1], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop_half_inv[2], M)
  M .= g.tmp

  mul!(g.tmp, l.chkr_mu_inv, M)
  M .= g.tmp
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  end
  end #timeit
  nothing
end

function multiply_B_inv_right!(mc::AbstractDQMC{CBAssaad}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_inv_right!" begin
  
  interaction_matrix_exp!(mc, slice, -1., s.eV)
  mul!(g.tmp, M, s.eV)
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_mu_inv)
  M .= g.tmp

  mul!(g.tmp, M, l.chkr_hop_half_inv[2])
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_hop_inv[1])
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_hop_half_inv[2])
  M .= g.tmp
  end
  end #timeit
  nothing
end

function multiply_daggered_B_left!(mc::AbstractDQMC{CBAssaad}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_daggered_B_left!" begin
  
  interaction_matrix_exp!(mc, slice, 1., s.eV)
  mul!(g.tmp, l.chkr_hop_half_dagger[2], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop_dagger[1], M)
  M .= g.tmp
  mul!(g.tmp, l.chkr_hop_half_dagger[2], M)
  M .= g.tmp

  # s.eV == adjoint(s.eV) and l.chkr_mu == adjoint(l.chkr_mu)
  mul!(g.tmp, l.chkr_mu, M)
  M .= g.tmp
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  end
  end #timeit
  nothing
end



# -------------------------------------------------------
#  				Generic checkerboard
# -------------------------------------------------------
function multiply_B_left!(mc::AbstractDQMC{CBGeneric}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  p = mc.p
  g = mc.g
  s = mc.s
  a = mc.a
  @timeit a.to "multiply_B (combined)" begin
  @timeit a.to "multiply_B_left!" begin

  # @timeit a.to "Bleft_construct_eV" begin
  interaction_matrix_exp!(mc,slice,1.,s.eV)
  # end
  # @timeit a.to "Bleft_mult_eV" begin
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  # end
  mul!(g.tmp, l.chkr_mu, M)
  M .= g.tmp

  # @timeit a.to "Bleft_mult_eT" begin
  @inbounds @views begin
    for i in reverse(1:l.n_folded)
      mul!(g.tmp, l.chkr_hop_half_folded_rev[i], M)
      M .= g.tmp
    end
    mul!(g.tmp, l.chkr_hop[1], M)
    M .= g.tmp
    for i in 1:l.n_folded
      mul!(g.tmp, l.chkr_hop_half_folded[i], M)
      M .= g.tmp
    end
  end
  # end
  end
  end #timeit
  nothing
end

function multiply_B_right!(mc::AbstractDQMC{CBGeneric}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  p = mc.p
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_right!" begin

  @inbounds @views begin
    for i in reverse(1:l.n_folded)
      mul!(g.tmp, M, l.chkr_hop_half_folded[i])
      M .= g.tmp
    end
    mul!(g.tmp, M, l.chkr_hop[1])
    M .= g.tmp
    for i in 1:l.n_folded
      mul!(g.tmp, M, l.chkr_hop_half_folded_rev[i])
      M .= g.tmp
    end
  end

  interaction_matrix_exp!(mc,slice,1.,s.eV)
  mul!(g.tmp, M, l.chkr_mu)
  M .= g.tmp
  mul!(g.tmp, M, s.eV)
  M .= g.tmp
  end
  end #timeit
  nothing
end

function multiply_B_inv_left!(mc::AbstractDQMC{CBGeneric}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  p = mc.p
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_inv_left!" begin
  
  @inbounds @views begin
    for i in reverse(1:l.n_folded)
      mul!(g.tmp, l.chkr_hop_half_inv_folded_rev[i], M)
      M .= g.tmp
    end
    mul!(g.tmp, l.chkr_hop_inv[1], M)
    M .= g.tmp
    for i in 1:l.n_folded
      mul!(g.tmp, l.chkr_hop_half_inv_folded[i], M)
      M .= g.tmp
    end
  end

  interaction_matrix_exp!(mc, slice, -1., s.eV)
  mul!(g.tmp, l.chkr_mu_inv, M)
  M .= g.tmp
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  end
  end #timeit
  nothing
end

function multiply_B_inv_right!(mc::AbstractDQMC{CBGeneric}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  p = mc.p
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_B_inv_right!" begin
  
  interaction_matrix_exp!(mc, slice, -1., s.eV)
  mul!(g.tmp, M, s.eV)
  M .= g.tmp
  mul!(g.tmp, M, l.chkr_mu_inv)
  M .= g.tmp

  @inbounds @views begin
    for i in reverse(1:l.n_folded)
      mul!(g.tmp, M, l.chkr_hop_half_inv_folded[i])
      M .= g.tmp
    end
    mul!(g.tmp, M, l.chkr_hop_inv[1])
    M .= g.tmp
    for i in 1:l.n_folded
      mul!(g.tmp, M, l.chkr_hop_half_inv_folded_rev[i])
      M .= g.tmp
    end
  end
  end
  end #timeit
  nothing
end

function multiply_daggered_B_left!(mc::AbstractDQMC{CBGeneric}, slice::Int, M::AbstractMatrix{T}) where T<:Number
  l = mc.l
  p = mc.p
  g = mc.g
  s = mc.s
  a = mc.a
  @mytimeit a.to "multiply_B (combined)" begin
  @mytimeit a.to "multiply_daggered_B_left!" begin
    
  @inbounds @views begin
    for i in reverse(1:l.n_folded)
      mul!(g.tmp, l.chkr_hop_half_dagger_folded_rev[i], M)
      M .= g.tmp
    end
    mul!(g.tmp, l.chkr_hop_dagger[1], M)
    M .= g.tmp
    for i in 1:l.n_folded
      mul!(g.tmp, l.chkr_hop_half_dagger_folded[i], M)
      M .= g.tmp
    end
  end

  interaction_matrix_exp!(mc, slice, 1., s.eV)
  # s.eV == adjoint(s.eV) and l.chkr_mu == adjoint(l.chkr_mu)
  mul!(g.tmp, l.chkr_mu, M)
  M .= g.tmp
  mul!(g.tmp, s.eV, M)
  M .= g.tmp
  end
  end #timeit
  nothing
end