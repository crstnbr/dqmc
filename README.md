[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3603345.svg)](https://doi.org/10.5281/zenodo.3603345)

         o.OOOo.    .oOOOo.   Oo      oO  .oOOOo.  
         O    `o  .O     o.  O O    o o .O     o  
         o      O o       O  o  o  O  O o              Determinant quantum Monte Carlo code
         O      o O       o  O   Oo   O o              for simulating quantum critical metals!
         o      O o       O  O        o o           
         O      o O    Oo o  o        O O              (In pure Julia!)
         o    .O' `o     O'  o        O `o     .o   
         OooOO'    `OoooO Oo O        o  `OoooO'  

| **Build Status**                                                                                |  **License**                                                                                |
|:-----------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| ![][lifecycle-img] [![][travis-ci-img]][travis-ci-url] [![](https://codecov.io/gh/crstnbr/dqmc/branch/master/graph/badge.svg?token=jTD6HWrHVh)][codecov-url] | [![][license-img]][license-url] |

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://crstnbr.github.io/dqmc/dev
[github-ci-img]: https://github.com/crstnbr/dqmc/workflows/Run%20tests/badge.svg
[github-ci-url]: https://github.com/crstnbr/dqmc/actions?query=workflow%3A%22Run+tests%22
[travis-ci-img]: https://travis-ci.com/crstnbr/dqmc.svg?token=ZhpR15dDPdpyVFTzrPfp&branch=master
[travis-ci-url]: https://travis-ci.com/crstnbr/dqmc
[codecov-img]: https://codecov.io/gh/crstnbr/dqmc/branch/master/graph/badge.svg?token=jTD6HWrHVh
[codecov-url]: https://codecov.io/gh/crstnbr/dqmc

[slack-url]: https://slackinvite.julialang.org/
[slack-img]: https://img.shields.io/badge/chat-on%20slack-yellow.svg
[license-img]: https://img.shields.io/badge/License-MIT-red.svg
[license-url]: https://opensource.org/licenses/MIT

[lifecycle-img]: https://img.shields.io/badge/lifecycle-stable-blue.svg


**Determinant quantum Monte Carlo (DQMC)** code for simulating a quantum critical metal, a Fermi sea coupled to antiferromagnetic bosonic fluctuations, in two spatial dimensions.

<img src="https://github.com/crstnbr/dqmc/raw/master/viz.png" width=400px>

A version of this code has been used to produce (most of) the results in the following paper:

> [*Hierarchy of energy scales in an O(3) symmetric antiferromagnetic quantum critical metal: a Monte Carlo study*<br>Carsten Bauer, Yoni Schattner, Simon Trebst, Erez Berg](https://arxiv.org/abs/2001.00586)

### Performance comparison

The figure below shows a comparison of three different DQMC codes written in C++, Fortran, and Julia. Specifically, it shows the time it takes to perform one sweep of local updates in space and imaginary time for a spin-fermion model (studied in the paper linked above). All kinds of special features, such as a small magnetic flux to improve finite size effects, are turned off.

Codes:

* C++ code by Max Gerlach ([repository](https://github.com/maxhgerlach/detqmc), [used in this paper](https://journals.aps.org/prb/abstract/10.1103/PhysRevB.95.035124)).
* Private Fortran code by Yoni Schattner ([used in this paper](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.117.097002)).
* Julia DQMC implementation in this repository.

<img src="https://github.com/crstnbr/dqmc/raw/master/speed_comp.png" width=600px>

### Settings

**Environmental variables:**

* `LATTICES`: folder with ALPS XML lattice files (mandatory unless you're me)
* `WALLTIME`: Set a walltime limit for the algorithm. (optional)
* `JULIA_DQMC`: path to the root of this repo (optional, currently only used in `live.jl/ipynb` and `test_live.ipynb` to activate the environment)

### Modes
Special modes as indicated by fields in `dqmc.in.xml`:

* `EDRUN`: if set to true, temporal gradients and quartic term in bosonic action are turned off.
* `TIMING`: stop after thermalization phase and report speed and allocations of all major functions.
