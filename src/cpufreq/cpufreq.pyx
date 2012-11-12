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

cpdef cpu_exists(unsigned int cpu):
    return not cpufreq_cpu_exists(cpu)

cpdef int cpus_number():
    # hopefully there is always at least one cpu...
    cdef unsigned int i = 1
    while True:
        if cpufreq_cpu_exists(i) != 0:
            return i
        i += 1

cpdef unsigned long get_freq_kernel(unsigned int cpu) except 0:
    cdef unsigned long freq = cpufreq_get_freq_kernel(cpu)
    if not freq:
        raise ValueError
    return freq

cpdef get_all_freqs_kernel():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        res[i] = cpufreq_get_freq_kernel(i)
    return res

cpdef unsigned long get_freq_hardware(unsigned int cpu) except 0:
    cdef unsigned long freq = cpufreq_get_freq_hardware(cpu)
    if not freq:
        raise ValueError
    return freq

cpdef get_all_freqs_hardware():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        res[i] = cpufreq_get_freq_hardware(i)
    return res

cpdef unsigned long get_transition_latency(unsigned int cpu) except 0:
    cdef unsigned long res = cpufreq_get_transition_latency(cpu)
    if not res:
        raise ValueError
    return res

cpdef get_all_transition_latencies():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        res[i] = cpufreq_get_transition_latency(i)
    return res

cpdef get_hardware_limits(unsigned int cpu):
    cdef unsigned long _min
    cdef unsigned long _max
    cdef int res = cpufreq_get_hardware_limits(cpu, &_min, &_max)
    if res:
        raise ValueError
    return _min, _max

cpdef get_all_hardware_limits():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_hardware_limits(i)
        except:
            pass
    return res

cpdef get_driver(unsigned int cpu):
    cdef char *_driver = cpufreq_get_driver(cpu)
    if not _driver:
        raise ValueError
    try:
        driver = _driver.decode('utf-8')
    finally:
        cpufreq_put_driver(_driver)
    return driver

cpdef get_all_drivers():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_driver(i)
        except:
            pass
    return res

cdef class Policy:
    def __cinit__(self):
        self.governor = None
    cdef int set_policy(self, cpufreq_policy *_policy) except -1:
        self.max = _policy.max
        self.min = _policy.min
        if _policy.governor:
            self.governor = _policy.governor.decode('utf-8')
        else:
            self.governor = None
        return 0

cpdef Policy get_policy(unsigned int cpu):
    cdef cpufreq_policy *_policy = cpufreq_get_policy(cpu)
    if not _policy:
        raise ValueError
    cdef Policy policy = Policy()
    try:
        policy.set_policy(_policy)
    finally:
        cpufreq_put_policy(_policy)
    return policy

cpdef get_all_policies():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_policy(i)
        except:
            pass
    return res

cpdef get_available_governors(unsigned int cpu):
    cdef cpufreq_available_governors *governors
    governors = cpufreq_get_available_governors(cpu)
    if not governors:
        raise ValueError
    res = []
    cdef cpufreq_available_governors *p = governors
    while p:
        if p.governor and p.governor[0]:
            res.append(p.governor.decode("utf-8"))
        p = p.next
    cpufreq_put_available_governors(governors)
    return res

cpdef get_all_available_governors():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_available_governors(i)
        except:
            pass
    return res

cpdef get_available_frequencies(unsigned int cpu):
    cdef cpufreq_available_frequencies *frequencies
    frequencies = cpufreq_get_available_frequencies(cpu)
    if not frequencies:
        raise ValueError
    res = []
    cdef cpufreq_available_frequencies *p = frequencies
    while p:
        res.append(p.frequency)
        p = p.next
    cpufreq_put_available_frequencies(frequencies)
    return res

cpdef get_all_available_frequencies():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_available_frequencies(i)
        except:
            pass
    return res

cpdef get_affected_cpus(unsigned int cpu):
    cdef cpufreq_affected_cpus *cpus
    cpus = cpufreq_get_affected_cpus(cpu)
    if not cpus:
        raise ValueError
    res = []
    cdef cpufreq_affected_cpus *p = cpus
    while p:
        res.append(p.cpu)
        p = p.next
    cpufreq_put_affected_cpus(cpus)
    return res

cpdef get_all_affected_cpus():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_affected_cpus(i)
        except:
            pass
    return res

cpdef get_related_cpus(unsigned int cpu):
    cdef cpufreq_affected_cpus *cpus
    cpus = cpufreq_get_related_cpus(cpu)
    if not cpus:
        raise ValueError
    res = []
    cdef cpufreq_affected_cpus *p = cpus
    while p:
        res.append(p.cpu)
        p = p.next
    cpufreq_put_related_cpus(cpus)
    return res

cpdef get_all_related_cpus():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_related_cpus(i)
        except:
            pass
    return res

cdef class Stat:
    def __cinit__(self, unsigned long frequency,
                  unsigned long long time_in_state):
        self.frequency = frequency
        self.time_in_state = time_in_state
    def __init__(self, unsigned long frequency,
                 unsigned long long time_in_state):
        pass

cpdef get_stats(unsigned int cpu):
    cdef cpufreq_stats *cpus
    cdef unsigned long long total_time
    cpus = cpufreq_get_stats(cpu, &total_time)
    if not cpus:
        raise ValueError
    res = []
    cdef cpufreq_stats *p = cpus
    while p:
        res.append(Stat(p.frequency, p.time_in_state))
        p = p.next
    cpufreq_put_stats(cpus)
    return total_time, res

cpdef get_all_stats():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        try:
            res[i] = get_stats(i)
        except:
            pass
    return res

cpdef unsigned long get_transitions(unsigned int cpu) except 0:
    cdef unsigned long res = cpufreq_get_transitions(cpu)
    if not res:
        raise ValueError
    return res

cpdef get_all_transitions():
    cdef int n = cpus_number()
    res = [None] * n
    for i in range(n):
        res[i] = cpufreq_get_transitions(i)
    return res

cpdef set_policy(unsigned int cpu, unsigned long min_freq=0,
                 unsigned long max_freq=0, governor=None):
    cdef cpufreq_policy policy
    cdef int ret = 0
    if governor is not None:
        governor = governor.encode("")
        if min_freq and max_freq:
            policy.min = min_freq
            policy.max = max_freq
            policy.governor = governor
            ret = cpufreq_set_policy(cpu, &policy)
            if ret < 0:
                raise ValueError
            return
        else:
            ret = cpufreq_modify_policy_governor(cpu, governor)
            if ret < 0:
                raise ValueError
    if min_freq:
        ret = cpufreq_modify_policy_min(cpu, min_freq)
        if ret < 0:
            raise ValueError
    if max_freq:
        ret = cpufreq_modify_policy_max(cpu, max_freq)
        if ret < 0:
            raise ValueError

cpdef set_frequency(unsigned int cpu,
                    unsigned long target_frequency):
    cdef int ret
    ret = cpufreq_set_frequency(cpu, target_frequency)
    if ret < 0:
        raise ValueError
