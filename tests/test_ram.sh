
# Error on unset variables
set -u

if [ -n "${ZSH_VERSION-}" ]; then
  SHUNIT_PARENT="$0"
  setopt shwordsplit ksh_arrays
fi

LP_ENABLE_RAM=1

typeset -a os outputs values_avail values_total

# Fake trivial Linux.
# Should be the first one, for test_ram_threshold below.
os+=('Linux')
outputs+=('MemTotal: 2048 kB
MemAvailable: 1024 kB')
values_avail+=('1024')
values_total+=('2048')

# Linux 5.4.0-139-generic #156-Ubuntu SMP Fri Jan 20 17:27:18 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
os+=('Linux')
outputs+=('MemTotal:        8033668 kB
MemFree:         2722348 kB
MemAvailable:    6899116 kB
Buffers:         1360936 kB
Cached:          2226412 kB
SwapCached:            0 kB
Active:          2558628 kB
Inactive:        1491516 kB
Active(anon):     455688 kB
Inactive(anon):    46872 kB
Active(file):    2102940 kB
Inactive(file):  1444644 kB
Unevictable:        4504 kB
Mlocked:              32 kB
SwapTotal:       2097148 kB
SwapFree:        2097148 kB
Dirty:               336 kB
Writeback:             0 kB
AnonPages:        467004 kB
Mapped:           451292 kB
Shmem:             53164 kB
KReclaimable:     939992 kB
Slab:            1126700 kB
SReclaimable:     939992 kB
SUnreclaim:       186708 kB
KernelStack:        5796 kB
PageTables:         8952 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:     6113980 kB
Committed_AS:    2605400 kB
VmallocTotal:   34359738367 kB
VmallocUsed:       71264 kB
VmallocChunk:          0 kB
Percpu:             4464 kB
HardwareCorrupted:     0 kB
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
ShmemPmdMapped:        0 kB
FileHugePages:         0 kB
FilePmdMapped:         0 kB
CmaTotal:              0 kB
CmaFree:               0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
Hugetlb:               0 kB
DirectMap4k:      564428 kB
DirectMap2M:     7710720 kB
DirectMap1G:     1048576 kB
'
)
values_avail+=('6899116')
values_total+=('8033668')


# (Free?)BSD, unknown version
os+=('FreeBSD')
outputs+=('usable memory = 34346901504 (32755 MB)
avail memory  = 33139134464 (31603 MB)')
values_avail+=('33139134464')
values_total+=('34346901504')

# Darwin 22.3.0 Darwin Kernel Version 22.3.0: Mon Jan 30 20:42:11 PST 2023; root:xnu-8792.81.3~2/RELEASE_X86_64 x86_64
os+=('Darwin')
outputs+=('Mach Virtual Memory Statistics: (page size of 4096 bytes)
Pages free:                               77936.
Pages active:                           1729321.
Pages inactive:                         1684334.
Pages speculative:                        45972.
Pages throttled:                              0.
Pages wired down:                        620324.
Pages purgeable:                          18622.
"Translation faults":                 134215056.
Pages copy-on-write:                    2741383.
Pages zero filled:                     97842470.
Pages reactivated:                       658037.
Pages purged:                            470473.
File-backed pages:                       786795.
Anonymous pages:                        2672832.
Pages stored in compressor:              105679.
Pages occupied by compressor:             35785.
Decompressions:                          256471.
Compressions:                            447621.
Pageins:                                4513634.
Pageouts:                                 11829.
Swapins:                                   6144.
Swapouts:                                  6656.
')
# free  * page_size
# 77936 * 4096
values_avail+=('319225856')
# (free + active + inactive + speculative + throttled + wired down + occupied by compressor) * page_size
# (77936+ 1729321+ 1684334  + 45972       + 0         + 620324     + 35785                 ) * 4096
values_total+=('17177280512')


function test_ram() {
    _LP_LINUX_RAM_FILE="${SHUNIT_TMPDIR}/lpraminfo"
    _LP_BSD_RAM_FILE="${SHUNIT_TMPDIR}/lpraminfo"
    LP_RAM_THRESHOLD_PERC=100 # Available mem% will always lesser or equal than 100.
    LP_RAM_THRESHOLD=$(( (1<<63)-1 )) # MAXINT in 64 bits.
    LP_RAM_PRECISION=0
    typeset lp_ram_avail_bytes lp_ram_total_bytes lp_ram_used_bytes
    # Set to null because we don't use the `if _lp_ram` guard construction.
    typeset lp_ram_used_perc= lp_ram_perc=

    # Iterate over tests.
    for (( i=0; i < ${#values_avail[@]}; i++ )); do
        # Load Linux version.
        uname() { printf "${os[$i]}"; }
        . ../liquidprompt --no-activate
        unset -f uname

        # Linux and BSD.
        printf '%s\n' "${outputs[$i]}" > "${SHUNIT_TMPDIR}/lpraminfo"
        # Darwin.
        vm_stat() {
            printf '%s\n' "${outputs[$i]}"
        }
        __lp_ram_bytes
        assertEquals "${LP_OS} available memory #$i." "${values_avail[$i]}" "${lp_ram_avail_bytes}"
        assertEquals "${LP_OS} total memory #$i." "${values_total[$i]}" "${lp_ram_total_bytes}"
        assertEquals "${LP_OS} used memory #$i." "$((lp_ram_total_bytes-lp_ram_avail_bytes))" "${lp_ram_used_bytes}"

        _lp_ram
        assertEquals "${LP_OS} untouched available memory #$i." "${values_avail[$i]}" "${lp_ram_avail_bytes}"
        assertEquals "${LP_OS} untouched total memory #$i." "${values_total[$i]}" "${lp_ram_total_bytes}"
        assertEquals "${LP_OS} untouched used memory #$i." "$((lp_ram_total_bytes-lp_ram_avail_bytes))" "${lp_ram_used_bytes}"
        assertEquals "${LP_OS} available percentage #$i." "$((lp_ram_avail_bytes*100/lp_ram_total_bytes))" "${lp_ram_perc}"
        # assertEquals "${LP_OS} used percentage #$i." "$((lp_ram_used_bytes*100/lp_ram_total_bytes))" "${lp_ram_used_perc}"
    done
    unset -f vm_stat
}


function test_ram_threshold()
{
    _LP_LINUX_RAM_FILE="${SHUNIT_TMPDIR}/lpraminfo"
    LP_MARK_RAM="M"
    LP_RAM_PRECISION=0
    typeset lp_ram_perc=

    # 0 = no error, 1 = error.
    local OK=0 NO=1
    local MAXINT=$(( (1<<63)-1 )) # MAXINT in 64 bits.

    # Load Linux version.
    uname() { printf 'Linux'; }
    . ../liquidprompt --no-activate
    unset -f uname

    LP_RAM_THRESHOLD=0

    # Fake trivial meminfo = 1024/2048 kB.
    printf '%s\n' "${outputs[0]}" > "$_LP_LINUX_RAM_FILE"
    LP_RAM_THRESHOLD_PERC=100
    _lp_ram
    assertEquals "Tests expect fake trivial meminfo" "50" "$lp_ram_perc"

    LP_RAM_THRESHOLD_PERC=0
    _lp_ram
    assertEquals "No display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$NO" "$?"

    LP_RAM_THRESHOLD_PERC=100
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=50
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=51
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=49
    _lp_ram
    assertEquals "No display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$NO" "$?"

    # At least one or both thresholds.
    LP_RAM_THRESHOLD_PERC=100
    LP_RAM_THRESHOLD=0
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=0
    LP_RAM_THRESHOLD=$MAXINT
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=100
    LP_RAM_THRESHOLD=$MAXINT
    _lp_ram
    assertEquals "Display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$OK" "$?"

    LP_RAM_THRESHOLD_PERC=0
    LP_RAM_THRESHOLD=0
    _lp_ram
    assertEquals "No display at $lp_ram_perc <= $LP_RAM_THRESHOLD_PERC" "$NO" "$?"
}

. ./shunit2
