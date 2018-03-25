echo on

mex total_power3.c

mex likelihood_power2.c

mex part_moment.c

mex -DranSHR3 particle_resampling.c

mex ndellipse.c

echo off