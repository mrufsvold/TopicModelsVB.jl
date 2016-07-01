# TopicModelsVB.jl
A Julia Package for Variational Bayesian Topic Modeling.

Topic Modeling is concerned with discovering the latent low-dimensional thematic structure within corpora.  Modeling this latent structure is done using either [Markov chain Monte Carlo](https://en.wikipedia.org/wiki/Markov_chain_Monte_Carlo) (MCMC) methods, or [variational Bayesian](https://en.wikipedia.org/wiki/Variational_Bayesian_methods) (VB) methods.  The former approach is slower, but unbiased.  Given infinite time, MCMC will fit the desired model exactly.  The latter method is faster (often much faster), but biased, since one must approximate distributions in order to ensure tractability.  This package takes the latter approach to topic modeling.

## Dependencies

```julia
Pkg.add("Distributions.jl")
```

## Install

```julia
Pkg.clone("git://github.com/esproff/TopicModelsVB.jl.git")
```

## Datasets
Included in TopicModelsVB.jl are three datasets:

1. National Science Foundation Abstracts 1989 - 2003:
  * 30000 documents
  * 20323 lexicon

2. CiteULike Science Article Database:
  * 16980 documents
  * 8000 lexicon
  * 5551 users

3. Macintosh Magazine Article Collection 1975 - 2014:
  * 75011 documents
  * 15113 lexicon

## Corpus
Let's begin with the Corpus data structure.  The Corpus data structure has been designed for maximum ease-of-use.  Datasets must still be cleaned and put into the appropriate format, but once a dataset is in the proper format and read into a corpus, it can easily be molded and modified to meet the user's needs.

There are four plaintext files that make up a corpus:
 * docfile
 * lexfile
 * userfile
 * titlefile
 
None of these files are mandatory to read a corpus, and in fact reading no files will result in an empty corpus.  However in order to train a model a docfile will be necessary, since it contains all quantitative data known about the documents in the corpus.  On the other hand, the lex, user and title files are used solely for interpreting output.

The docfile should be a plaintext file containing lines of delimited numerical values.  Each document is a block of lines, the number of which depends on what information is known about the documents.  Since a document is at its essence a list of terms, each document *must* contain at least one line containing a nonempty list of delimited positive integer values corresponding to the terms from which it is composed.  Any further lines in a document block are optional, however if they are present they must be present for all documents and must come in the following order:

* `terms`: A line of delimited positive integers corresponding to the terms which make up the document (this line is mandatory).

* `counts`: A line of delimited positive integers equal in length to the term line, corresponding to the number of times a particular term appears in a document (defaults to `ones(length(terms))`).

* `readers`: A line of delimited positive integers corresponding to those users which have read the document.

* `ratings`: A line of delimited positive integers equal in length to the `readers` line, corresponding to the rating each reader gave the document (defaults to `ones(length(readers))`).

* `stamp`: A numerical value in the range `[-inf, inf]` denoting the timestamp of the document.

An example of a single doc block from a docfile with all possible lines included:

```
...
4,10,3,100,57
1,1,2,1,3
1,9,10
1,1,5
19990112.0
...
```

The lex and user files are dictionaries mapping positive integers to terms and usernames (resp.).  For example,

```
1    this
2    is
3    a
4    lex
5    file
```

A userfile is identitcal to a lexfile, except usernames will appear in place of vocabulary terms.

Finally, a titlefile is simply a list of titles, not a dictionary, and is of the form:

```
title1
title2
title3
title4
title5
```

The order of these titles correspond to the order of document blocks in the associated docfile.

To read a corpus into TopicModelsVB.jl, use the following function:

```julia
readcorp(;docfile="", lexfile="", userfile="", titlefil="", delim=',', counts=false, readers=false, ratings=false, stamps=false)
```

The ```file``` keyword arguments indicate the path where the respective file is located.

It is often the case that even once files are correctly formatted and read, the corpus will still contain formatting defects which prevent it from being loaded into a model.  Therefore, before loading a corpus into a model, it is **very important** that one of the following is run:

```julia
fixcorp!(corp; kwargs...)
```

or

```julia
padcorp!(corp; kwargs...)
fixcorp!(corp; kwargs...)
```

Padding a corpus before fixing it will ensure that any documents which contain lex or user keys not in the lex or user dictionaries are not removed.  Instead, generic lex and user keys will be added as necessary to the lex and user dictionaries (resp.).

**Important:** A corpus is only a container for documents.  

Whenever you load a corpus into a model, a copy of that corpus is made, such that if you modify the original corpus at corpus-level (remove documents, re-order lex keys, etc.), this will not affect any corpus attached to a model.  However!  Since corpora are containers for their documents, modifying an individual document will affect this document in all corpora which contain it.  **Be very careful whenever modifying the internals of documents themselves, either manually or through the use of** `corp!` **functions**. 

## Models
The available models are as follows:

```julia
LDA(corp, K)
# Latent Dirichlet Allocation model with K topics.

fLDA(corp, K)
# Filtered latent Dirichlet allocation model with K topics.

CTM(corp, K)
# Correlated topic model with K topics.

fCTM(corp, K)
# Filtered correlated topic model with K topics.

DTM(corp, K, delta, pmodel)
# Dynamic topic model with K topics and ∆ = delta.

CTPF(corp, K, pmodel)
# Collaborative topic Poisson factorization model with K topics.
```

Notice that both `DTM` and `CTPF` have a `pmodel` argument.  It is **highly advisable** that you prime these final two models with a pretrained model from one of the first four, otherwise learning may take a prohibitively long time.

## Tutorial
### LDA
Let's begin our tutorial with a simple latent Dirichlet allocation (LDA) model with 9 topics, trained on the first 5000 documents from the NSF corpus.

```julia
using TopicModelsVB

srand(1)

nsfcorp = readcorp(:nsf)
nsfcorp.docs = nsfcorp[1:5000]
fixcorp!(nsfcorp)

# Notice that the post-fix lexicon is considerably smaller after removing all but the first 5000 docs.

nsflda = LDA(nsfcorp, 9)
train!(nsflda, iter=150, tol=0.0) # Setting tol=0.0 will ensure that all 150 iterations are completed.
                                  # If you don't want to watch the ∆elbo, set chkelbo=151.
# training...

showtopics(nsflda, cols=9)
```

```
topic 1         topic 2         topic 3          topic 4        topic 5       topic 6      topic 7          topic 8         topic 9
data            research        species          research       research      cell         research         theory          chemistry
project         study           research         systems        university    protein      project          problems        research
research        experimental    plant            system         support       cells        data             study           metal
study           high            study            design         students      proteins     study            research        reactions
earthquake      systems         populations      data           program       gene         economic         equations       chemical
ocean           theoretical     genetic          algorithms     science       plant        important        work            study
water           phase           plants           based          scientists    genes        social           investigator    studies
studies         flow            evolutionary     control        award         studies      understanding    geometry        program
measurements    physics         population       project        dr            molecular    information      project         organic
field           quantum         data             computer       project       research     work             principal       structure
provide         materials       dr               performance    scientific    specific     development      algebraic       molecular
time            properties      studies          parallel       sciences      function     theory           mathematical    dr
models          temperature     patterns         techniques     conference    system       provide          differential    compounds
results         model           relationships    problems       national      study        analysis         groups          surface
program         dynamics        determine        models         projects      important    policy           space           molecules
```

Now that we've trained our LDA model we can, if we want, take a look at the topic proportions for individual documents.  For instance, document 1 has topic breakdown:

```julia
nsflda.gamma[1] # = [0.036, 0.030, 189.312, 0.036, 0.049, 0.022, 8.728, 0.027, 0.025]
```
This vector of topic weights suggests that document 1 is mostly about biology, and in fact looking at the document text confirms this observation:

```julia
showdocs(nsflda, 1) # Could also have done showdocs(nsfcorp, 1).
```

```
 ●●● Doc: 1
 ●●● CRB: Genetic Diversity of Endangered Populations of Mysticete Whales: Mitochondrial DNA and Historical Demography
commercial exploitation past hundred years great extinction variation sizes
populations prior minimal population size current permit analyses effects 
differing levels species distributions life history...
```

On the other hand, some documents will be a combination of topics.  Consider the topic breakdown for document 25:

```julia
nsflda.gamma[25] # = [11.575, 44.889, 0.0204, 0.036, 0.049, 0.022, 0.020, 66.629, 0.025]

showdocs(nsflda, 25)
```

```
 ●●● Doc: 25
 ●●● Mathematical Sciences: Nonlinear Partial Differential Equations from Hydrodynamics
work project continues mathematical research nonlinear elliptic problems arising perfect
fluid hydrodynamics emphasis analytical study propagation waves stratified media techniques
analysis partial differential equations form basis studies primary goals understand nature 
internal presence vortex rings arise density stratification due salinity temperature...
```

We see that in this case document 25 appears to be about applications of mathematical physics to ocean currents, which corresponds precisely to a combination of topics 2 and 8, with a smaller but not insignificant weight on topic 1.

Furthermore, if we want to, we can also generate artificial corpora by using the ```gencorp``` function.  Generating artificial corpora will in turn run the underlying probabilistic graphical model as a generative process in order to produce entirely new collections of documents, let's try it out:

```julia
artifnsfcorp = gencorp(nsflda, 5000, 1e-5) # The third argument governs the amount of Laplace smoothing (defaults to 0.0).

artifsnflda = LDA(artifnsfcorp, 9)
train!(artifnsflda, iter=150, tol=0.0, chkelbo=15)

# training...

showtopics(artifnsflda, cols=9)
```

```
topic 1       topic 2          topic 3       topic 4          topic 5         topic 6         topic 7      topic 8         topic 9
cell          research         research      species          theory          data            chemistry    research        research
protein       project          university    plant            problems        project         research     study           systems
cells         study            students      research         study           research        reactions    systems         design
gene          data             support       study            research        earthquake      metal        phase           system
proteins      economic         program       evolutionary     equations       study           chemical     experimental    data
plant         social           science       genetic          work            studies         organic      flow            algorithms
studies       important        scientists    population       project         water           structure    theoretical     based
genes         understanding    scientific    plants           investigator    ocean           program      materials       parallel
research      work             award         populations      principal       measurements    study        high            performance
molecular     information      sciences      dr               geometry        program         dr           quantum         techniques
specific      theory           projects      data             differential    important       molecular    physics         computer
mechanisms    provide          dr            patterns         mathematical    time            synthesis    properties      problems
system        development      project       relationships    algebraic       models          compounds    temperature     control
role          human            national      evolution        methods         seismic         surface      dynamics        project
study         political        provide       variation        analysis        field           studies      proposed        methods
```

One thing we notice so far is that despite producing what are clearly coherent topics, many of the top words in each topic are words such as *research*, *study*, *data*, etc.  While such terms would be considered informative in a generic corpus, they are effectively stop words in a corpus composed of science article abstracts.  Such corpus-specific stop words will be missed by most generic stop word lists, and can be a difficult to pinpoint and individually remove prior to training.  Thus let's change our model to a *filtered* latent Dirichlet allocation (fLDA) model.

```julia
srand(1)

nsfflda = fLDA(nsfcorp, 9)
train!(nsfflda, iter=150, tol=0.0)

# training...

showtopics(nsfflda, cols=9)
```

```
topic 1         topic 2         topic 3          topic 4           topic 5          topic 6       topic 7          topic 8         topic 9
earthquake      theoretical     species          algorithms        university       cell          economic         theory          chemistry
ocean           physics         plant            parallel          students         protein       social           equations       reactions
water           flow            genetic          performance       program          cells         theory           geometry        chemical
measurements    phase           populations      computer          science          plant         policy           mathematical    metal
program         quantum         evolutionary     processing        scientists       proteins      human            differential    program
soil            particle        plants           applications      sciences         gene          change           algebraic       molecular
climate         temperature     population       network           scientific       genes         political        groups          organic
seismic         phenomena       patterns         networks          conference       molecular     public           solutions       surface
global          energy          variation        software          national         function      science          mathematics     compounds
sea             measurements    dna              computational     projects         expression    decision         finite          molecules
response        laser           ecology          efficient         engineering      regulation    people           dimensional     electron
earth           particles       food             distributed       year             plants        labor            spaces          university
solar           numerical       test             program           workshop         dna           market           functions       reaction
pacific         liquid          ecological       power             months           mechanisms    scientific       manifolds       synthesis
damage          fluid           host             programming       mathematical     membrane      factors          professor       spectroscopy
```

We can now see that many of the most troublesome corpus-specific stop words have been automatically filtered out, while those that remain are mostly those which tend to cluster within their own, more generic, topic.

### CTM
For our final example using the NSF corpus, let's upgrade our model to a filtered *correlated* topic model (fCTM).

```julia
srand(1)

nsffctm = fCTM(nsfcorp, 9)
train!(nsffctm, iter=150, tol=0.0)

# training...

showtopics(nsffctm, 20, cols=9)
```

```
topic 1         topic 2         topic 3          topic 4           topic 5         topic 6       topic 7        topic 8         topic 9
earthquake      flow            species          design            university      protein       social         theory          chemistry
ocean           experimental    plant            algorithms        support         cell          economic       equations       chemical
water           materials       genetic          models            students        cells         theory         investigator    reactions
program         model           populations      parallel          program         proteins      policy         geometry        metal
measurements    phase           plants           computer          science         gene          models         mathematical    molecular
soil            theoretical     evolutionary     performance       scientists      plant         change         differential    program
models          optical         population       model             award           genes         human          algebraic       dr
climate         temperature     dr               processing        dr              molecular     public         groups          properties
seismic         particle        patterns         applications      scientific      dr            model          space           organic
global          models          evolution        network           sciences        regulation    political      solutions       university
sea             heat            relationships    networks          conference      plants        examine        mathematics     surface
effects         properties      dna              software          national        expression    case           spaces          electron
response        growth          variation        efficient         projects        mechanisms    issues         dimensional     molecules
pacific         fluid           effects          computational     engineering     dna           people         finite          compounds
earth           numerical       biology          distributed       year            membrane      theoretical    functions       reaction
solar           surface         molecular        programming       researchers     growth        effects        questions       synthesis
model           quantum         reproductive     estimation        workshop        binding       factors        manifolds       spectroscopy
atmospheric     effects         animals          program           months          acid          decision       properties      energy
damage          laser           growth           implementation    mathematical    enzymes       labor          professor       dynamics
change          phenomena       test             algorithm         faculty         site          market         operators       materials
```

Because the topics in the fLDA model were already so well defined, there's little room to improve topic coherence by upgrading to the fCTM model, however what's most interesting about the CTM and fCTM models is the ability to look at topic correlations.

Based on the top 20 terms in each topic, we might tentatively assign the following topic labels:

* topic 1: *Earth Science*
* topic 2: *Physics*
* topic 3: *Sociobiology*
* topic 4: *Computer Science*
* topic 5: *Academia*
* topic 6: *Microbiology*
* topic 7: *Economics*
* topic 8: *Mathematics*
* topic 9: *Chemistry*

Now let's take a look at the topic-covariance matrix:

```julia
model.sigma

# Top 3 off-diagonal positive entries, sorted in descending order:
model.sigma[4,8] # 15.005
model.sigma[3,6] # 13.219
model.sigma[2,9] # 7.502

# Top 3 negative entries, sorted in ascending order:
model.sigma[6,8] # -22.347
model.sigma[3,8] # -20.198
model.sigma[4,6] # -14.160
```

According to the list above, the most closely related topics are topics 4 and 8, which correspond to the *Computer Science* and *Mathematics* topics, followed closely by 3 and 6, corresponding to the topics *Sociobiology* and *Microbiology*, and then by 2 and 9, corresponding to *Physics* and *Mathematics*.

As for the most unlikely topic pairings, first are topics 6 and 8, corresponding to *Microbiology* and *Mathematics*, followed closely by topics 3 and 8, corresponding to *Sociobiology* and *Mathematics*, and then third are topics 4 and 6, corresponding to *Computer Science* and *Microbiology*.

Interestingly, the topic which is least correlated with all other topics is not the *Academia* topic (which is the second least correlated), but instead the *Economics* topic.

```julia
sum(abs(model.sigma[:,7])) - model.sigma[7,7] # Economics topic, absolute off-diagonal covariance 5.732.
sum(abs(model.sigma[:,5])) - model.sigma[5,5] # Academia topic, absolute off-diagonal covariance 18.766.
```

Taking a closer look at topic-covariance matrix, it appears that there is a tendency within the natural sciences for the softer sciences to use slightly more academic buzzwords, while the harder sciences tend to eschew them.  The *Economics* topic also happens to be the only non-natural science found among the 9 topics, and thus a potential lack of overlapping lexicon with the natural sciences may have been what led to its observed lack of correlation with the other 8 topics.

### DTM
Now that we have covered static topic models, let's transition to the dynamic topic model (DTM).  The dynamic topic model discovers the temporal-dynamics of topics which, nevertheless, remain thematically static.  A good example of a topic which is thematically-static, yet exhibits an evolving lexicon, is *Computer Storage*.  Methods of data storage have evolved rapidly in the last 40 years, evolving from punch cards, to 5-inch floppy disks, to smaller hard disks, to zip drives and cds, to dvds and platter hard drives, and now to flash drives, solid-state drives and cloud storage, all accompanied by the rise and fall of computer companies which manufacture (or at one time manufactured) these products.

As an example, let's load the corpus of Macintosh articles, drawn from the magazines *MacWorld* and *MacAddict*, published between the years 1984 - 2005.  We sample 400 articles randomly from each year, and break time periods into 2 year intervals.

```julia
srand(1)

cmagcorp = readcorp(:mac)

cmagcorp.docs = vcat([sample(filter(doc -> round(doc.stamp / 100) == y, cmagcorp.docs), 400, replace=false) for y in 1984:2005]...)

fixcorp!(corp, stop=true, order=false, b=100, len=10) # Remove words that which appear < 100 times and documents of length < 10.

cmaglda = LDA(corp, 9)
train!(cmagflda, iter=150, chkelbo=151)

# training...

cmagdtm = DTM(cmagcorp, 9, 200, cmagflda)
```

However before training our DTM model, let's manually set one of its hyperparameters:

```julia
cmagdtm.sigmasq=10.0 # 'sigmasq' defaults to 1.0.
```

This hyperparameter governs both how quickly the same topic mixes within different time intervals, as well as how much variance between time intervals is allowed overall.  Since computer technology is a rapidly evolving field, increasing the value of this parameter will hopefully lead to better quality topic dynamics, as well as a quicker fit for our model.

```julia
train!(cmagdtm, iter=200, chkelbo=20) # This will likely take about 5 hours on a personal computer.
                                      # Convergence for all other models is worst-case quadratic,
                                      # while DTM convergence is linear or at best super-linear.
# training...

showtopics(model, 20, topics=5)
```

```
topics
```

### CTPF
For our final model, we take a look at the collaborative topic Poisson factorization (CTPF) model.  CTPF is a collaborative filtering topic model which uses the latent thematic structure of documents to improve the quality of document recommendations, beyond what would be capable using just the document-user matrix.  This blending of latent thematic structure with the document-user matrix not only improves recommendation accuracy, but also mitigates the cold-start problem of recommending to users never-before-seen documents.  As an example, let's load the CiteULike dataset into a corpus and then randomly remove a single reader from each of the documents.

```julia
import Distributions.sample

srand(1)

citeucorp = readcorp(:citeu)

testukeys = Int[]
for doc in citeucorp
    index = sample(1:length(doc.readers), 1)[1]
    push!(testukeys, doc.readers[index])
    deleteat!(doc.readers, index)
    deleteat!(doc.ratings, index)
end
```

**Important:** We refrain from fixing our corpus in this case, first because the CiteULike dataset is pre-packaged and thus pre-fixed, but more importantly, because removing user keys from documents and then fixing our corpus may result in a re-ordering of its user dictionary, which would in turn invalidate our test set.

After training, we will evaluate model quality by measuring our model's success at imputing the correct user back into each of the document libraries.

It's also worth noting that after removing a single reader from each document, 158 of the documents now have 0 readers.

```julia
sum([isempty(doc.readers) for doc in corp]) # = 158
```

Fortunately, since CTPF can, if need be, depend entirely on thematic structure when making recommendations, this poses no problem for the model.

Now that we have set up our experiment, we instantiate and train a CTPF model on our corpus.  Furthermore, since we're not interested in the interpretability of the topics, we'll instantiate our model with a larger than usual number of topics (K=30), and then run it for a relatively short number of iterations (iter=5).

```julia
pmodel = LDA(citeucorp, 30)
train!(pmodel, iter=150, chkelbo=15) # This will likely take 10 - 15 minutes on a personal computer.

# training...

citeuctpf = CTPF(citeucorp, 30, pmodel) # Note: 'pmodel' defaults to a 150 iteration LDA model.
train!(citeuctpf, iter=5)

# training...
```

Finally, we evaluate the accuracy of our model against the test set, where baseline for mean accuracy is 0.5.

```julia
acc = Float64[]
for (d, u) in enumerate(testukeys)
    rank = findin(citeuctpf.drecs[d], u)[1]
    nrlen = length(citeuctpf.drecs[d])
    push!(acc, (nrlen - rank) / (nrlen - 1))
end

@show mean(acc) # mean(acc) = 0.913
```

We can see that, on average, our model ranks the true hidden reader in the top 9% of all non-readers for each document.

Let's also take a look at the top recommendations for a particular document(s):

```julia
testukeys[1] # = 216
acc[1] # = 0.973

showdrecs(model, 1, 152, cols=1)
```
```
 ●●● Doc: 1
 ●●● The metabolic world of Escherichia coli is not small
...
148. #user4157
149. #user1543
150. #user817
151. #user1642
152. #user216
```
as well as those for a particular user(s):

```julia
showurecs(model, 216, 426)
```
```
 ●●● User: 216
...
422. Improving loss resilience with multi-radio diversity in wireless networks
423. Stochastic protein expression in individual cells at the single molecule level
424. Dynamical and correlation properties of the Internet
425. Multifractal Network Generator
426. The metabolic world of Escherichia coli is not small
```

We can also take a more holistic and informal approach to evaluating model quality.  Let's take a look at the first few documents in user 216's library,

```julia
showlibs(citeuctpf, 216)
```

```
 ●●● User: 216
 • Network motifs: simple building blocks of complex networks.
 • The large-scale organization of metabolic networks.
 • Here is the evidence, now what is the hypothesis? The complementary roles of inductive and hypothesis-driven science in the post-genomic era
 • Classification and Regression Trees
 • {Evolutionary rate in the protein interaction network}
 ...
```
 
 user 216 appears to be interested in subjects at the intersection of network theory and microbiology.  Now compare this with the top 10 recommendations made by our model,
 
```julia
 showurecs(citeuctpf, 216, 10)
```
 
```
 ●●● User: 216
1.  The hallmarks of cancer.
2.  The structure and function of complex networks
3.  Collective dynamics of 'small-world' networks.
4.  Emergence of scaling in random networks
5.  Statistical mechanics of complex networks
6.  MicroRNA Control in the Immune System: Basic Principles
7.  Power laws, Pareto distributions and Zipf's law
8.  Exploring complex networks
9.  Network biology: understanding the cell's functional organization.
10. Systems Biology: A Brief Overview
```

## GPGPU Support

Hopefully coming soon...

## Types

```julia
VectorList{T}
# Array{Array{T,1},1}

MatrixList{T}
# Array{Array{T,2},1}

Document(terms; counts=ones(length(terms)), readers=Int[], ratings=ones(length(readers)), stamp=-Inf, title="")
# FIELDNAMES:
# terms::Vector{Int}
# counts::Vector{Int}
# readers::Vector{Int}
# ratings::Vector{Int}
# stamp::Float64
# title::UTF8String

Corpus(;docs=Document[], lex=[], users=[])
# FIELDNAMES:
# docs::Vector{Document}
# lex::Dict{Int, UTF8String}
# users::Dict{Int, UTF8String}

TopicModel
# abstract type

LDA(corp, K) <: TopicModel
# Latent Dirichlet allocation
# 'K' - number of topics.

fLDA(corp, K) <: TopicModel
# Filtered latent Dirichlet allocation

CTM(corp, K) <: TopicModel
# Correlated topic model

fCTM(corp, K) <: TopicModel
# Filtered correlated topic model

DTM(corp, K, delta, pmodel) <: TopicModel
# Dynamic topic model
# 'delta'  - time-interval size.
# 'pmodel' - pre-trained model of type Union{LDA, fLDA, CTM, fCTM}.

CTPF(corp, K, pmodel) <: TopicModel
# Collaborative topic Poisson factorization
```


## Functions
### Generic Functions

```julia
isnegative(x::Union{Real, Array{Real}})
# Take Real or Array{Real} and return Bool or Array{Bool} (resp.).

ispositive(x::Union{Real, Array{Real}})
# Take Real or Array{Real} and return Bool or Array{Bool} (resp.).

tetragamma(.)
# polygamma(2, .)

logsumexp(x::Array{Real})
# Overflow safe log(sum(exp(x))).

addlogistic(x::Array{Real}, region::Int)
# Overflow safe additive logistic function.
# 'region' is optional, across columns: 'region' = 1, rows: 'region' = 2.

partition(xs::Union{Vector, UnitRange}, n::Int)
# 'n' must be positive.
# Return VectorList containing contiguous portions of xs of length n (includes remainder).
# e.g. partition([1,-7.1,"HI",5,5], 2) == Vector[[1,-7.1],["HI",5],[5]]
```

### Document/Corpus Functions
```julia
checkdoc(doc::Document)
# Verify that all Document fields have legal values.

checkcorp(corp::Corpus)
# Verify that all Corpus fields have legal values.

readcorp(;docfile::AbstractString="", lexfile::AbstractString="", userfile::AbstractString="", titlefile::AbstractString="", delim::Char=',', counts::Bool=false, readers::Bool=false, ratings::Bool=false, stamps::Bool=false)
# Read corpus from plaintext files.

writecorp(corp::Corpus; docfile::AbstractString="", lexfile::AbstractString="", userfile::AbstractString="", titlefile::AbstractString="", delim::Char=',', counts::Bool=false, readers::Bool=false, ratings::Bool=false, stamps::Bool=false)
# Write corpus to plaintext files.

abridgecorp!(corp::Corpus; stop::Bool=false, order::Bool=true, b::Int=1)
# Abridge corpus.
# If stop = true, stop words are removed.
# If order = false, order is ignored and multiple seperate occurrences of words are stacked and the associated counts increased.
# All terms which appear < b times are removed from documents.

trimcorp!(corp::Corpus; lex::Bool=true, terms::Bool=true, users::Bool=true, readers::Bool=true)
# Those values which appear in the indicated fields of documents, yet don't appear in the corpus dictionaries, are removed.

compactcorp!(corp::Corpus; lex::Bool=true, users::Bool=true, alphabet::Bool=true)
# Compact a corpus by relabeling lex and/or userkeys so that they form a unit range.
# If alphabet=true the lex and/or user dictionaries are alphabetized.

padcorp!(corp::Corpus; lex::Bool=true, users::Bool=true)
# Pad a corpus by entering generic values for lex and/or userkeys which appear in documents but not in the lex/user dictionaries.

cullcorp!(corp::Corpus; terms::Bool=false, readers::Bool=false, len::Int=1)
# Culls the corpus of documents which contain lex and/or user keys in a document's terms/readers (resp.) fields yet don't appear in the corpus dictionaries.
# All documents of length < len are removed.

fixcorp!(corp::Corpus; lex::Bool=true, terms::Bool=true, users::Bool=true, readers::Bool=true, stop::Bool=false, order::Bool=true, b::Int=1, len::Int=1, alphabet::Bool=true)
# Fixes a corp by running the following four functions in order:
# abridgecorp!(corp, stop=stop, order=order, b=b)
# trimcorp!(corp, lex=lex, terms=terms, users=users, readers=readers)
# cullcorp!(corp, len=len)	
# compactcorp!(corp, lex=lex, users=users, alphabet=alphabet)

showdocs(corp::Corpus, docs::Union{Document, Vector{Document}, Int, Vector{Int}, UnitRange{Int}})
# Display the text and title of a document(s).

getlex(corp::Corpus)
# Collect sorted values from the lex dictionary.

getusers(corp::Corpus)
# Collect sorted values from the user dictionary.
```

### Model Functions

```julia
showdocs(model::TopicModel, docs::Union{Document, Vector{Document}, Int, Vector{Int}, UnitRange{Int}})

checkmodel(model::TopicModel)
# Verify that all model fields have legal values.

train!(model::Union{LDA, fLDA, CTM, fCTM}; iter::Int=150, tol::Real=1.0, niter=1000, ntol::Real=1/model.K^2, viter::Int=10, vtol::Real=1/model.K^2, chkelbo::Int=1)
# Train one of the following models: LDA, fLDA, CTM, fCTM.
# 'iter'    - maximum number of iterations through the corpus.
# 'tol'     - absolute tolerance for ∆elbo as a stopping criterion.
# 'niter'   - maximum number of iterations for Newton's and interior-point Newton's methods.
# 'ntol'    - tolerance for change in function value as a stopping criterion for Newton's and interior-point Newton's methods.
# 'viter'   - maximum number of iterations for optimizing variational parameters (at the document level).
# 'vtol'    - tolerance for change in variational parameter values as stopping criterion.
# 'chkelbo' - number of iterations between ∆elbo checks (for both evaluation and convergence checking).

train!(dtm::DTM; iter::Int=150, tol::Real=1.0, niter=1000, ntol::Real=1/dtm.K^2, cgiter::Int=10, cgtol::Real=1/dtm.T^2, chkelbo::Int=1)
# Train DTM.
# 'cgiter' - maximum number of iterations for the Polak-Ribière conjugate gradient method.
# 'cgtol'  - tolerance for change in function value as stopping criterion for Polak-Ribière conjugate gradient method.

train!(ctpf::CTPF; iter::Int=150, tol::Real=1.0, viter::Int=10, vtol::Real=1/ctpf.K^2, chkelbo::Int=1)
# Train CTPF.

gendoc(model::Union{LDA, fLDA, CTM, fCTM}, a::Real=0.0)
# Generate a generic document from model parameters by running the associated graphical model as a generative process.
# 'a' - amount of Laplace smoothing to apply to the topic-term distributions ('a' must be nonnegative).

gencorp(model::Union{LDA, fLDA, CTM, fCTM}, corpsize::Int, a::Real=0.0)
# Generate a generic corpus of size 'corpsize' from model parameters.

showtopics(model::TopicModel, N::Int=min(15, model.V); topics::Union{Int, Vector{Int}}=collect(1:model.K), cols::Int=4)
# Display the top 'N' words for each topic in 'topics', defaults to 4 columns per line.

showtopics(dtm::DTM, N::Int=min(15, dtm.V); topics::Union{Int, Vector{Int}}=collect(1:dtm.K), times::Union{Int, Vector{Int}}=collect(1:dtm.T), cols::Int=4)
# Display the top 'N' words for each topic in 'topics' and each time interval in 'times', defaults to 4 columns per line.

showlibs(ctpf::CTPF, users::Union{Int, Vector{Int}})
# Show the document(s) in a user's library.

showdrecs(ctpf::CTPF, docs::Union{Int, Vector{Int}}, U::Int=min(16, ctpf.U); cols::Int=4)
# Show the top 'U' user recommendations for a document(s), defaults to 4 columns per line.

showurecs(ctpf::CTPF, users::Union{Int, Vector{Int}}, M::Int=min(10, ctpf.M); cols::Int=1)
# Show the top 'M' document recommendations for a user(s), defaults to 1 column per line.
# If a document has no title, the documents index in the corpus will be shown instead.
```

## Bibliography
1. Latent Dirichlet Allocation (2003); Blei, Ng, Jordan. [pdf](http://www.cs.columbia.edu/~blei/papers/BleiNgJordan2003.pdf)
2. Correlated Topic Models (2006); Blei, Lafferty. [pdf](http://www.cs.columbia.edu/~blei/papers/BleiLafferty2006.pdf)
3. Dynamic Topic Models (2006); Blei, Lafferty. [pdf](http://www.cs.columbia.edu/~blei/papers/BleiLafferty2006a.pdf)
4. Content-based Recommendations with Poisson Factorization (2014); Gopalan, Charlin, Blei. [pdf](http://www.cs.columbia.edu/~blei/papers/GopalanCharlinBlei2014.pdf)
5. Numerical Optimization (2006); Nocedal, Wright. [Amazon](https://www.amazon.com/Numerical-Optimization-Operations-Financial-Engineering/dp/0387303030)
6. Machine Learning: A Probabilistic Perspective (2012); Murphy. [Amazon](https://www.amazon.com/Machine-Learning-Probabilistic-Perspective-Computation/dp/0262018020/ref=tmm_hrd_swatch_0?_encoding=UTF8&qid=&sr=)
