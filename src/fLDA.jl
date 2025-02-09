mutable struct fLDA <: TopicModel
	"Filtered latent Dirichlet allocation."

	K::Int
	M::Int
	V::Int
	N::Vector{Int}
	C::Vector{Int}
	corp::Corpus
	topics::VectorList{Int}
	eta::Float64
	alpha::Vector{Float64}
	kappa::Vector{Float64}
	kappa_old::Vector{Float64}
	kappa_temp::Vector{Float64}
	beta::Matrix{Float64}
	beta_old::Matrix{Float64}
	beta_temp::Matrix{Float64}
	Elogtheta::VectorList{Float64}
	Elogtheta_old::VectorList{Float64}
	gamma::VectorList{Float64}
	tau::VectorList{Float64}
	tau_old::VectorList{Float64}
	phi::MatrixList{Float64}
	elbo::Float64

	function fLDA(corp::Corpus, K::Integer)
		check_corp(corp)
		K > 0 || throw(ArgumentError("Number of topics must be a positive integer."))

		M, V, U = size(corp)
		N = [length(doc) for doc in corp]
		C = [size(doc) for doc in corp]

		topics = [collect(1:V) for _ in 1:K]

		eta = 0.5
		alpha = ones(K)
		kappa = rand(Dirichlet(V, 1.0))
		kappa_old = copy(kappa)
		kappa_temp = zeros(V)
		beta = rand(Dirichlet(V, 1.0), K)'
		beta_old = copy(beta)
		beta_temp = zeros(K, V)
		Elogtheta = [-eulergamma * ones(K) .- digamma(K) for _ in 1:M]
		Elogtheta_old = deepcopy(Elogtheta)
		gamma = [ones(K) for _ in 1:M]
		tau = [fill(eta, N[d]) for d in 1:M]
		tau_old = deepcopy(tau)
		phi = [ones(K, N[d]) / K for d in 1:min(M, 1)]
		elbo = 0
	
		model = new(K, M, V, N, C, copy(corp), topics, eta, alpha, kappa, kappa_old, kappa_temp, beta, beta_old, beta_temp, Elogtheta, Elogtheta_old, gamma, tau, tau_old, phi, elbo)
		return model
	end
end

function Elogptheta(model::fLDA, d::Int)
	"Compute E_q[log(P(theta))]."

	x = finite(loggamma(sum(model.alpha))) - finite(sum(loggamma.(model.alpha))) + dot(model.alpha .- 1, model.Elogtheta[d])
	return x
end

function Elogpc(model::fLDA, d::Int)
	"Compute E_q[log(P(c))]."

	counts = model.corp[d].counts
	x = log(@boink model.eta^dot(model.tau[d], counts) * (1 - model.eta)^(model.C[d] - dot(model.tau[d], counts)))
	return x
end

function Elogpz(model::fLDA, d::Int)
	"Compute E_q[log(P(z))]."

	counts = model.corp[d].counts
	x = dot(model.phi[1] * counts, model.Elogtheta[d])
	return x
end

function Elogpw(model::fLDA, d::Int)
	"Compute E_q[log(P(w))]."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	x = sum(model.phi[1] .* log.(@boink model.beta[:,terms]) * (counts .* model.tau[d])) + dot(counts .* (1 .- model.tau[d]), log.(@boink model.kappa[terms]))
	return x
end

function Elogqtheta(model::fLDA, d::Int)
	"Compute E_q[log(q(theta))]."

	x = -entropy(Dirichlet(model.gamma[d]))
	return x
end

function Elogqc(model::fLDA, d::Int)
	"Compute E_q[log(q(c))]."

	counts = model.corp[d].counts
	x = -sum([c * entropy(Bernoulli(model.tau[d][n])) for (n, c) in enumerate(counts)])
	return x
end

function Elogqz(model::fLDA, d::Int)
	"Compute E_q[log(q(z))]."

	counts = model.corp[d].counts
	x = -sum([c * entropy(Categorical(model.phi[1][:,n])) for (n, c) in enumerate(counts)])
	return x
end

function update_elbo!(model::fLDA)
	"Update the evidence lower bound."

	model.elbo = 0
	for d in 1:model.M
		terms = model.corp[d].terms
		model.phi[1] = additive_logistic(model.tau_old[d]' .* log.(@boink model.beta_old[:,terms]) .+ model.Elogtheta_old[d], dims=1)
		model.elbo += Elogptheta(model, d) + Elogpc(model, d) + Elogpz(model, d) + Elogpw(model, d) - Elogqtheta(model, d) - Elogqc(model, d) - Elogqz(model, d)
	end

	return model.elbo
end

function update_eta!(model::fLDA)
	"Update eta."
	"Analytic."

	model.eta = sum([dot(model.tau[d], model.corp[d].counts) for d in 1:model.M]) / sum(model.C)
end

function update_alpha!(model::fLDA, niter::Integer, ntol::Real)
	"Update alpha."
	"Interior-point Newton's method with log-barrier and back-tracking line search."

	Elogtheta_sum = sum([model.Elogtheta[d] for d in 1:model.M])

	nu = model.K
	for _ in 1:niter
		rho = 1.0
		alpha_grad = (nu ./ model.alpha + model.M * (digamma(sum(model.alpha)) .- digamma.(model.alpha))) + Elogtheta_sum
		alpha_invhess_diag = -1 ./ (model.M * trigamma.(model.alpha) + nu ./ model.alpha.^2)
		p = (alpha_grad .- dot(alpha_grad, alpha_invhess_diag)  * (model.M * trigamma(sum(model.alpha)) + sum(alpha_invhess_diag))) .* alpha_invhess_diag
		
		while minimum(model.alpha - rho * p) < 0
			rho *= 0.5
		end	
		@finite model.alpha -= rho * p
		
		if (rho * norm(alpha_grad) < ntol) & (nu / model.K < ntol)
			break
		end
		nu *= 0.5
	end
	@positive model.alpha
end

function update_kappa!(model::fLDA)
	"Reset kappa variables."
	"Analytic."

	model.kappa_old = model.kappa
	model.kappa = model.kappa_temp ./ sum(model.kappa_temp)
	model.kappa_temp = zeros(model.V)
end

function update_kappa!(model::fLDA, d::Int)
	"Update kappa."
	"Analytic."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	model.kappa_temp[terms] += (1 .- model.tau[d]) .* counts
end

function update_beta!(model::fLDA)
	"Reset beta variables."

	model.beta_old = model.beta
	model.beta = model.beta_temp ./ sum(model.beta_temp, dims=2)
	model.beta_temp = zeros(model.K, model.V)
end

function update_beta!(model::fLDA, d::Int)
	"Update beta."
	"Analytic."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	model.beta_temp[:,terms] += model.phi[1] .* (model.tau[d] .* counts)'
end

function update_Elogtheta!(model::fLDA, d::Int)
	"Update E[log(theta)]."
	"Analytic."
	
	model.Elogtheta_old[d] = model.Elogtheta[d]
	model.Elogtheta[d] = digamma.(model.gamma[d]) .- digamma(sum(model.gamma[d]))
end

function update_gamma!(model::fLDA, d::Int)
	"Update gamma."
	"Analytic."

	counts = model.corp[d].counts
	@positive model.gamma[d] = model.alpha + model.phi[1] * counts	
end

function update_tau!(model::fLDA, d::Int)
	"Update tau."
	"Analytic."

	model.tau_old[d] = model.tau[d]

	terms = model.corp[d].terms
	model.tau[d] = model.eta ./ (@boink model.eta .+ (1 - model.eta) * (model.kappa[terms] .* vec(prod(model.beta[:,terms].^-model.phi[1], dims=1))))
end

function update_phi!(model::fLDA, d::Int)
	"Update phi."
	"Analytic."

	terms = model.corp[d].terms
	model.phi[1] = additive_logistic(model.tau[d]' .* log.(@boink model.beta[:,terms]) .+ model.Elogtheta[d], dims=1)
end

function train!(model::fLDA; iter::Integer=150, tol::Real=1.0, niter::Integer=1000, ntol::Real=1/model.K^2, viter::Integer=10, vtol::Real=1/model.K^2, checkelbo::Real=1, printelbo::Bool=true)
	"Coordinate ascent optimization procedure for filtered latent Dirichlet allocation variational Bayes algorithm."

	check_model(model)
	all([tol, ntol, vtol] .>= 0)										|| throw(ArgumentError("Tolerance parameters must be nonnegative."))
	all([iter, niter, viter] .>= 0)										|| throw(ArgumentError("Iteration parameters must be nonnegative."))
	(isa(checkelbo, Integer) & (checkelbo > 0)) | (checkelbo == Inf)	|| throw(ArgumentError("checkelbo parameter must be a positive integer or Inf."))
	all([isempty(doc) for doc in model.corp]) && (iter = 0)
	(checkelbo <= iter) && update_elbo!(model)

	for k in 1:iter
		for d in 1:model.M	
			for _ in 1:viter
				update_phi!(model, d)
				update_tau!(model, d)
				update_gamma!(model, d)
				update_Elogtheta!(model, d)
				if norm(model.Elogtheta[d] - model.Elogtheta_old[d]) < vtol
					break
				end
			end
			update_beta!(model, d)
			update_kappa!(model, d)
		end
		update_beta!(model)
		update_kappa!(model)
		update_alpha!(model, niter, ntol)
		#update_eta!(model)	
		
		if check_elbo!(model, checkelbo, printelbo, k, tol)
			break
		end
	end

	model.topics = [reverse(sortperm(vec(model.beta[i,:]))) for i in 1:model.K]
	nothing
end
