function decompose_udv!(A::Matrix{T}) where T<:Number

  Base.LinAlg.LAPACK.gesvd!('A','A',A)

  # F = svdfact!(A) # based on Base.LinAlg.LAPACK.gesdd!('A',A)
  # return F[:U], F[:S], F[:Vt]
end

function decompose_udv(A::Matrix{T}) where T<:Number
  X = copy(A)
  return decompose_udv!(X)
end

function decompose_udt!(M::Matrix{N}, U::Matrix{N}, D::Vector{Float64}, T::Matrix{N}, R::Matrix{N}) where N<:Number
  U[:], R[:], p = qr(M, Val{true}; thin=true)
  p_T = copy(p); p_T[p] = collect(1:length(p))
  D[:] = abs.(real(diag(triu(R))))[:]
  T[:] = (spdiagm(1./D) * R)[:, p_T]
end

function decompose_udt(A::Matrix{X}) where X<:Number
  Q, R, p = qr(A, Val{true}; thin=false)
  p_T = copy(p); p_T[p] = collect(1:length(p))
  D = abs.(real(diag(triu(R))))
  T = (spdiagm(1./D) * R)[:, p_T]
  return Q, D, T
end

function expm_diag!(A::Matrix{T}) where T<:Number
  F = eigfact!(A)
  return F[:vectors] * spdiagm(exp(F[:values])) * ctranspose(F[:vectors])
end

function lu_det(M)
    L, U, p = lu(M)
    return prod(diag(L)) * prod(diag(U))
end