# interaction_matrix_exp = exp(- power delta_tau V(slice)), with power = +- 1.
function interaction_matrix_exp(p::Parameters, l::Lattice, slice::Int, power::Float64=1.)
  eV = zeros(Complex{Float64}, p.flv * l.sites, p.flv * l.sites)

  C = blockview(l, eV, 1, 1)
  S = blockview(l, eV, 1, 2)
  R = blockview(l, eV, 1, 4)
  for i in 1:l.sites
    C[i,i] = p.interaction_cosh[i,slice]
    S[i,i] = (im * p.hsfield[2,i,slice] - p.hsfield[1,i,slice]) * power * p.interaction_sinh[i,slice]
    R[i,i] = (-p.hsfield[3,i,slice]) * power * p.interaction_sinh[i,slice]
  end

  cS = conj(S)
  mR = -R
  blockreplace!(l,eV,2,1,cS)
  blockreplace!(l,eV,2,2,C)
  blockreplace!(l,eV,2,3,mR)

  blockreplace!(l,eV,3,2,mR)
  blockreplace!(l,eV,3,3,C)
  blockreplace!(l,eV,3,4,cS)

  blockreplace!(l,eV,4,1,R)
  blockreplace!(l,eV,4,3,S)
  blockreplace!(l,eV,4,4,C)

  return eV
end


blockview{T<:Number}(l::Lattice, A::Matrix{T}, row::Int, col::Int) = view(A, (row-1)*l.sites+1:row*l.sites, (col-1)*l.sites+1:col*l.sites)
function blockreplace!{T<:Number}(l::Lattice, A::Matrix{T}, row::Int, col::Int, B::Union{Matrix{T},SubArray{T,2}})
  A[(row-1)*l.sites+1:row*l.sites, (col-1)*l.sites+1:col*l.sites] = B
  nothing
end


# calculate p.flv x p.flv (4x4 for O(3) model) interaction matrix exponential for given op
function interaction_matrix_exp_op(p::Parameters, l::Lattice, op::Vector{Float64}, power::Float64=1.)
  sh = power * sinh(p.lambda * p.delta_tau*norm(op))/norm(op)
  Cii = cosh(p.lambda * p.delta_tau*norm(op))
  Sii = (im * op[2] - op[1]) * sh
  Rii = (-op[3]) * sh

  return [Cii Sii 0 Rii; conj(Sii) Cii -Rii 0; 0 -Rii Cii conj(Sii); Rii 0 Sii Cii]
end
# Small optimization left to do here.


function interaction_matrix_slow(p::Parameters, l::Lattice, slice::Int, power::Float64=1.)
  C = zeros(l.sites,l.sites)
  S = zeros(Complex{Float64}, l.sites,l.sites)
  R = zeros(l.sites,l.sites)
  for i in 1:l.sites
    sh = power * sinh(p.lambda * p.delta_tau * norm(p.hsfield[:,i,slice]))/norm(p.hsfield[:,i,slice])
    C[i,i] = cosh(p.lambda * p.delta_tau * norm(p.hsfield[:,i,slice]))
    S[i,i] = (im * p.hsfield[2,i,slice] - p.hsfield[1,i,slice]) * sh
    R[i,i] = (-p.hsfield[3,i,slice]) * sh
  end
  Z = zeros(l.sites,l.sites)

  return [C S Z R; conj(S) C -R Z; Z -R C conj(S); R Z S C]
end


"""
Precalculation of sinh and cosh terms in interaction matrix
"""
function update_interaction_sinh_cosh_all(p::Parameters, l::Lattice)
  for n in 1:p.slices
    for i in 1:l.sites
      p.interaction_sinh[i,n] = sinh(p.lambda * p.delta_tau * norm(p.hsfield[:,i,n]))/norm(p.hsfield[:,i,n])
      p.interaction_cosh[i,n] = cosh(p.lambda * p.delta_tau * norm(p.hsfield[:,i,n]))
    end
  end
end

function update_interaction_sinh_cosh(p::Parameters, l::Lattice, site::Int, slice::Int, new_op::Vector{Float64})
  p.interaction_sinh[site,slice] = sinh(p.lambda * p.delta_tau * norm(new_op))/norm(new_op)
  p.interaction_cosh[site,slice] = cosh(p.lambda * p.delta_tau * norm(new_op))
end

function init_interaction_sinh_cosh(p::Parameters, l::Lattice)
  p.interaction_sinh = zeros(l.sites,p.slices)
  p.interaction_cosh = zeros(l.sites,p.slices)

  update_interaction_sinh_cosh_all(p,l)
end