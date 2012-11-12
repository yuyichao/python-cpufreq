#   Copyright (C) 2012~2012 by Yichao Yu
#   yyc1992@gmail.com
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

from libc.string cimport *
from libc.stdio cimport *
from libc.stdint cimport *
from libc.stdlib cimport *
from cpufreq._cpufreq cimport *

cpdef cpu_exists(unsigned int cpu)
cpdef unsigned long get_freq_kernel(unsigned int cpu) except 0
cpdef unsigned long get_freq_hardware(unsigned int cpu) except 0
cpdef unsigned long get_transition_latency(unsigned int cpu) except 0
cpdef get_hardware_limits(unsigned int cpu)
cpdef get_driver(unsigned int cpu)
cdef class Policy:
    cdef cpufreq_policy *_policy
cpdef Policy get_policy(unsigned int cpu)
cpdef get_available_governors(unsigned int cpu)
cpdef get_available_frequencies(unsigned int cpu)
cpdef get_affected_cpus(unsigned int cpu)
cpdef get_related_cpus(unsigned int cpu)
cdef class Stat:
    cdef readonly unsigned long frequency
    cdef readonly unsigned long long time_in_state
cpdef get_stats(unsigned int cpu)
cpdef unsigned long get_transitions(unsigned int cpu) except 0
cpdef set_policy(unsigned int cpu, unsigned long min_freq=*,
                 unsigned long max_freq=*, governor=*)
cpdef set_frequency(unsigned int cpu,
                    unsigned long target_frequency)
