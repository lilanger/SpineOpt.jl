# Introduction

*SpineOpt.jl* is an integrated energy systems optimization model created as part of the 
[Spine project](http://www.spine-model.org/), striving towards adaptability for a multitude of modelling purposes.
The data-driven model structure allows for highly customizable energy system descriptions, as well as flexible
temporal and stochastic structures, without the need to alter the model source code directly.
The methodology is based on mixed-integer linear programming (MILP), and *SpineOpt* relies on
[*JuMP.jl*](https://github.com/JuliaOpt/JuMP.jl) for interfacing with the different solvers.

While, in principle, it is possible to run *SpineOpt* by itself, it has been designed to be used through the
[Spine toolbox](https://github.com/Spine-project/Spine-Toolbox), and take maximum advantage of the data and modelling
workflow management tools therein.
Thus, we highly recommend installing *Spine toolbox* as well, as outlined in the [Installation](@ref) guide.

## Contents

In order to make it easier for you to familiarize yourself with the documentation, here's a list of all the different
chapters, as well as descriptions of what they're about.

### Getting Started

As the name implies, this chapter contains guides for starting to use *SpineOpt.jl*
for the first time. The [Installation](@ref) section contains a step-by-step guide for how to install *SpineOpt.jl*
and *Spine Toolbox* on your computer. The [Setting up a workflow for SpineOpt in Spine Toolbox](@ref)
section explains how to set up and run *SpineOpt.jl* from *Spine Toolbox*.
The [Creating Your Own Model](@ref) section explains how to create a new model from scratch.
This includes a list of the necessary [Object Classes](@ref) and [Relationship Classes](@ref),
but for more information, you will probably need to consult the **Concept Reference** chapter.

### Concept Reference

This chapter lists and explains all the important *data and model structure related concepts*
to understand in *SpineOpt.jl*. For a mathematical modelling point of view, see the **Mathematical Formulation**
chapter instead. The [Basics of the model structure](@ref) section briefly explains the general purpose of the most
important concepts, like [Object Classes](@ref) and [Relationship Classes](@ref). Meanwhile, the [Object Classes](@ref),
[Relationship Classes](@ref), [Parameters](@ref), and [Parameter Value Lists](@ref) sections contain detailed
explanations of each and every aspect of *SpineOpt.jl*, organized into the respective sections for clarity.

### Mathematical Formulation

This chapter provides the mathematical view of *SpineOpt.jl*, as some of the
methodology-related aspects of the model are more easily understood as math than Julia code. The [Variables](@ref)
section explains the purpose of each variable in the model, as well as how the variables are related to the different
[Object Classes](@ref) and [Relationship Classes](@ref). The [Constraints](@ref) section contains the mathematical
formulation of each constraint, as well as explanations to their purpose and how they are controlled via different
[Parameters](@ref). Finally, the [Objective](@ref) section explains the default objective function used in
*SpineOpt.jl*.

### Advanced Concepts

This chapter explains some of the more complicated aspects of *SpineOpt.jl* in more detail,
hopefully making it easier for you to better understand and apply them in your own modelling.
The first few sections focus on aspects of *SpineOpt.jl* that most users are likely to use,
or which are more or less required to understand for advanced use.
The [Temporal Framework](@ref) section explains how defining *time* works in *SpineOpt.jl*, and how it can be used
for different purposes. The [Stochastic Framework](@ref) section details how different stochastic structures can be
defined, how they interact with each other, and how this impacts writing [Constraints](@ref) in *SpineOpt.jl*.
The [Unit commitment](@ref) section explains how clustered unit-commitment is defined,
while the [Ramping and Reserves](@ref) section explains how to enable these operational details in your model.
The [Investment Optimization](@ref) section explains how to include investment variables in your models,
while the [User Constraints](@ref) section details how to include generic data-driven custom constraints.

The last few sections focus on highly specialized use-cases for *SpineOpt.jl*,
which are unlikely to be relevant for simple modelling tasks.
The [Decomposition](@ref) section explains the Benders decomposition implementation included in *SpineOpt.jl*,
as well as how to use it.
The remaining sections, namely [PTDF-Based Powerflow](@ref ptdf-based-powerflow),
[Pressure driven gas transfer](@ref pressure-driven-gas-transfer), [Lossless nodal DC power flows](@ref),
and [Representative days with seasonal storages](@ref), explain various use-case specific modelling approaches supported by *SpineOpt.jl*.