mutable struct fCTM <: TopicModel
	"Filtered correlated topic model."

	K::Int
	M::Int
	V::Int
	N::Vector{Int}
	C::Vector{Int}
	corp::Corpus
	topics::VectorList{Int}
	eta::Float64
	mu::Vector{Float64}
	sigma::Symmetric{Float64}
	invsigma::Symmetric{Float64}
	kappa::Vector{Float64}
	kappa_old::Vector{Float64}
	kappa_temp::Vector{Float64}
	beta::Matrix{Float64}
	beta_old::Matrix{Float64}
	beta_temp::Matrix{Float64}
	lambda::VectorList{Float64}
	lambda_old::VectorList{Float64}
	vsq::VectorList{Float64}
	logzeta::Vector{Float64}
	tau::VectorList{Float64}
	tau_old::VectorList{Float64}
	phi::MatrixList{Float64}
	elbo::Float64

	function fCTM(corp::Corpus, K::Integer)
		check_corp(corp)
		K > 0 || throw(ArgumentError("Number of topics must be a positive integer."))

		M, V, U = size(corp)
		N = [length(doc) for doc in corp]
		C = [size(doc) for doc in corp]

		topics = [collect(1:V) for _ in 1:K]

		eta = 0.5
		mu = zeros(K)
		sigma = Symmetric(Matrix{Float64}(I, K, K))
		invsigma = copy(sigma)
		kappa = rand(Dirichlet(V, 1.0))
		kappa_old = copy(kappa)
		kappa_temp = zeros(V)
		beta = rand(Dirichlet(V, 1.0), K)'
		beta_old = copy(beta)
		beta_temp = zeros(K, V)
		lambda = [zeros(K) for _ in 1:M]
		lambda_old = deepcopy(lambda)
		vsq = [ones(K) for _ in 1:M]
		logzeta = fill(0.5, M)
		tau = [fill(eta, N[d]) for d in 1:M]
		tau_old = deepcopy(tau)
		phi = [ones(K, N[d]) / K for d in 1:min(M, 1)]
		elbo = 0

		model = new(K, M, V, N, C, copy(corp), topics, eta, mu, sigma, invsigma, kappa, kappa_old, kappa_temp, beta, beta_old, beta_temp, lambda, lambda_old, vsq, logzeta, tau, tau_old, phi, elbo)
		return model
	end
end

function Elogpeta(model::fCTM, d::Int)
	"Compute E_q[log(P(eta))]."

	x = 0.5 * (logdet(model.invsigma) - model.K * log(2pi) - dot(diag(model.invsigma), model.vsq[d]) - dot(model.lambda[d] - model.mu, model.invsigma * (model.lambda[d] - model.mu)))
	return x
end

function Elogpc(model::fCTM, d::Int)
	"Compute E_q[log(P(c))]."

	counts = model.corp[d].counts
	x = log(@boink model.eta^dot(model.tau[d], counts) * (1 - model.eta)^(model.C[d] - dot(model.tau[d], counts)))
	return x
end

function Elogpz(model::fCTM, d::Int)
	"Compute E_q[log(P(z))]."

	counts = model.corp[d].counts
	x = dot(model.phi[1]' * model.lambda[d], counts) - model.C[d] * (sum(exp.(model.lambda[d] + 0.5 * model.vsq[d] .- model.logzeta[d])) + model.logzeta[d] - 1)
	return x
end

function Elogpw(model::fCTM, d::Int)
	"Compute E_q[log(P(w))]."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	x = sum(model.phi[1] .* log.(@boink model.beta[:,terms]) * (counts .* model.tau[d])) + dot(counts .* (1 .- model.tau[d]), log.(@boink model.kappa[terms]))
	return x
end

function Elogqeta(model::fCTM, d::Int)
	"Compute E_q[log(q(eta))]."

	x = -entropy(MvNormal(model.lambda[d], diagm(model.vsq[d])))
	return x
end

function Elogqc(model::fCTM, d::Int)
	"Compute E_q[log(q(c))]."

	counts = model.corp[d].counts
	x = -sum([c * entropy(Bernoulli(model.tau[d][n])) for (n, c) in enumerate(counts)])
	return x
end

function Elogqz(model::fCTM, d::Int)
	"Compute E_q[log(q(z))]."

	counts = model.corp[d].counts
	x = -sum([c * entropy(Categorical(model.phi[1][:,n])) for (n, c) in enumerate(counts)])
	return x
end

function update_elbo!(model::fCTM)
	"Update the evidence lower bound."

	model.elbo = 0
	for d in 1:model.M
		terms = model.corp[d].terms
		model.phi[1] = additive_logistic(model.tau_old[d]' .* log.(@boink model.beta_old[:,terms]) .+ model.lambda_old[d], dims=1)
		model.elbo += Elogpeta(model, d) + Elogpc(model, d) + Elogpz(model, d) + Elogpw(model, d) - Elogqeta(model, d) - Elogqc(model, d) - Elogqz(model, d)
	end

	return model.elbo
end

function update_eta!(model::fCTM)
	"Update eta."
	"Analytic."

	model.eta = sum([dot(model.tau[d], model.corp[d].counts) for d in 1:model.M]) / sum(model.C)
end

function update_mu!(model::fCTM)
	"Update mu."
	"Analytic."

	model.mu = sum(model.lambda) / model.M
end

function update_sigma!(model::fCTM)
	"Update sigma."
	"Analytic"

	model.sigma = Symmetric((diagm(sum(model.vsq)) + (hcat(model.lambda...) .- model.mu) * (hcat(model.lambda...) .- model.mu)') / model.M)
	model.invsigma = inv(model.sigma)
end

function update_kappa!(model::fCTM)
	"Reset kappa variables."
	"Analytic."

	model.kappa_old = model.kappa
	model.kappa = model.kappa_temp ./ sum(model.kappa_temp)
	model.kappa_temp = zeros(model.V)
end

function update_kappa!(model::fCTM, d::Int)
	"Update kappa."
	"Analytic."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	model.kappa_temp[terms] += (1 .- model.tau[d]) .* counts
end

function update_beta!(model::fCTM)
	"Reset beta variables."

	model.beta_old = model.beta
	model.beta = model.beta_temp ./ sum(model.beta_temp, dims=2)
	model.beta_temp = zeros(model.K, model.V)
end

function update_beta!(model::fCTM, d::Int)
	"Update beta."
	"Analytic."

	terms, counts = model.corp[d].terms, model.corp[d].counts
	model.beta_temp[:,terms] += model.phi[1] .* (model.tau[d] .* counts)'
end

function update_lambda!(model::fCTM, d::Int, niter::Integer, ntol::Real)
	"Update lambda."
	"Newton's method."

	model.lambda_old[d] = model.lambda[d]

	counts = model.corp[d].counts
	for _ in 1:niter
		lambda_grad = model.invsigma * (model.mu - model.lambda[d]) + model.phi[1] * counts - model.C[d] * exp.(model.lambda[d] + 0.5 * model.vsq[d] .- model.logzeta[d])
		lambda_negative_hess = model.invsigma + model.C[d] * Diagonal(exp.(model.lambda[d] + 0.5 * model.vsq[d] .- model.logzeta[d]))
		model.lambda[d] += lambda_negative_hess \ lambda_grad
		
		if norm(lambda_grad) < ntol
			break
		end
	end
end

function update_vsq!(model::fCTM, d::Int, niter::Integer, ntol::Real)
	"Update vsq."
	"Newton's method with back-tracking line search."

	for i in 1:model.K
		for _ in 1:niter
			rho = 1.0
			vsq_grad = -0.5 * (model.invsigma[i,i] + model.C[d] * exp(model.lambda[d][i] + 0.5 * model.vsq[d][i] - model.logzeta[d]) - 1 / model.vsq[d][i])
			vsq_invhess_diag = -1 / (0.25 * model.C[d] * exp(model.lambda[d][i] + 0.5 * model.vsq[d][i] - model.logzeta[d]) + 0.5 / model.vsq[d][i]^2)
			p = vsq_invhess_diag * vsq_grad
		
			while model.vsq[d][i] - rho * p <= 0
				rho *= 0.5
			end
			model.vsq[d][i] -= rho * p
			
			if rho * abs(vsq_grad) < ntol
				break
			end
		end
	end
	@positive model.vsq[d]
end

function update_logzeta!(model::fCTM, d::Int)
	"Update logzeta."
	"Analytic."

	model.logzeta[d] = logsumexp(model.lambda[d] + 0.5 * model.vsq[d])	
end

function update_tau!(model::fCTM, d::Int)
	"Update tau."
	"Analytic."

	model.tau_old[d] = model.tau[d]

	terms = model.corp[d].terms
	model.tau[d] = model.eta ./ (@boink model.eta .+ (1 - model.eta) * (model.kappa[terms] .* vec(prod(model.beta[:,terms].^-model.phi[1], dims=1))))
end

function update_phi!(model::fCTM, d::Int)
	"Update phi."
	"Analytic"

	terms = model.corp[d].terms
	model.phi[1] = additive_logistic(model.tau[d]' .* log.(@boink model.beta[:,terms]) .+ model.lambda[d], dims=1)
end

function train!(model::fCTM; iter::Integer=150, tol::Real=1.0, niter=1000, ntol::Real=1/model.K^2, viter::Integer=10, vtol::Real=1/model.K^2, checkelbo::Real=1, printelbo::Bool=true)	
	"Coordinate ascent optimization procedure for filtered correlated topic model variational Bayes algorithm."

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
				update_logzeta!(model, d)
				update_lambda!(model, d, niter, ntol)
				update_vsq!(model, d, niter, ntol)
				if norm(model.lambda[d] - model.lambda_old[d]) < vtol
					break
				end
			end
			update_beta!(model, d)
			update_kappa!(model, d)
		end
		update_beta!(model)
		update_kappa!(model)
		update_sigma!(model)
		update_mu!(model)
		#update_eta!(model)
		
		if check_elbo!(model, checkelbo, printelbo, k, tol)
			break
		end
	end

	model.topics = [reverse(sortperm(vec(model.beta[i,:]))) for i in 1:model.K]
	nothing
end
