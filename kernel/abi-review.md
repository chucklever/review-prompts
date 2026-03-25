# User/Kernel ABI Compatibility Review

Review a kernel patch for changes to user-visible interfaces and
evaluate those changes against the kernel's ABI stability rules.

This is not a regression analysis. It is a focused check for ABI
contract violations: removals, format changes, semantic changes,
or additions to interfaces that userspace programs observe.

## Reference Documents

The authoritative sources on ABI stability live in the kernel tree.
Read them before evaluating any interface change:

- `Documentation/ABI/README` -- the stable/testing/obsolete/removed
  directory scheme and the rules for moving an interface between
  those states
- `Documentation/process/stable-api-nonsense.rst` -- the kernel's
  position on internal vs. userspace API stability

Keep these rules in mind throughout:

1. **Stable ABI** (`Documentation/ABI/stable/`): backwards
   compatibility guaranteed for at least 2 years. Most interfaces
   (syscalls) are expected never to change.
2. **Testing ABI** (`Documentation/ABI/testing/`): mostly stable,
   can add features, must not break existing usage without grave
   cause.
3. **Obsolete ABI** (`Documentation/ABI/obsolete/`): still present,
   scheduled for removal on a documented date. A stable or testing
   interface cannot be removed without first moving to obsolete/;
   a patch that removes one directly is a High finding regardless
   of consumers.
4. **Undocumented interfaces**: absence of an ABI entry does not
   grant freedom to break. If userspace can observe it and has
   existed for a meaningful period, Linus's "don't break userspace"
   rule applies.
5. **debugfs**: no ABI guarantee in theory, but in practice
   interfaces should be designed for long-term maintenance.

## Task 1: Identify User-Visible Interface Changes

Read the full diff. For each hunk, determine whether it touches
a user-visible interface. User-visible means: observable by a
program running in userspace without loading a kernel module.
This includes debugfs and tracepoints; record their interface
type as `debugfs` or `tracepoint` and classify them with the
risk table like any other interface.

### Detection patterns

Scan the diff for these indicators. A match means the hunk
**may** touch a user-visible interface and requires classification.

#### procfs / sysfs / nfsdfs / other pseudo-filesystems

- `seq_printf`, `seq_puts`, `seq_putc`, `seq_write` -- format of
  virtual file output
- `DEFINE_SHOW_ATTRIBUTE`, `DEFINE_PROC_SHOW_ATTRIBUTE` -- file
  registration
- `sysfs_create_group`, `sysfs_create_file`, `device_create_file`
- `DEVICE_ATTR`, `DEVICE_ATTR_RO`, `DEVICE_ATTR_RW`, `__ATTR`,
  `sysfs_emit` -- sysfs attribute definitions and output
- `proc_create`, `proc_mkdir`, `remove_proc_entry`
- `ctl_table`, `proc_do*`, `register_sysctl*` -- sysctl knobs
- `module_param`, `module_param_named` --
  `/sys/module/*/parameters`
- `kobject_uevent`, `add_uevent_var` -- uevent contents
- Changes to file permissions (`S_IRUGO`, `S_IWUSR`, etc.)
- Addition or removal of files in pseudo-filesystem directory
  tables (arrays of structs with file names)

#### System calls and ioctls

- `SYSCALL_DEFINE`, `COMPAT_SYSCALL_DEFINE`
- `copy_to_user`, `copy_from_user` -- structure layout changes
- ioctl command definitions (`_IO`, `_IOR`, `_IOW`, `_IOWR`)
- Changes to uapi headers (`include/uapi/`)

#### Netlink and other wire formats

- `nla_put`, `nla_get`, netlink attribute definitions

#### Tracepoints (semi-stable)

- `TRACE_EVENT`, `DEFINE_EVENT` -- tracepoint format changes
  are technically unstable but perf/bpftrace users depend on them

#### Semantic changes (no fixed token)

These have no identifier to grep for. Look for them in every hunk
that touches a function reachable from one of the indicators above:

- A changed return value or errno on a syscall, ioctl, or
  pseudo-file write path
- A changed unit, default, valid range, or ordering of an existing
  output line, even when the `seq_printf` call itself is untouched

For each detected change, record:
- **File and line range**
- **Interface type**: procfs, sysfs, sysctl, syscall, ioctl,
  netlink, uapi header, tracepoint, debugfs, other
- **Nature of change**: addition, removal, format change,
  semantic change, permission change

## Task 2: Classify Each Interface Change

For each interface change found in Task 1:

### 2a: Check Documentation/ABI/

Search `Documentation/ABI/stable/`, `Documentation/ABI/testing/`,
and `Documentation/ABI/obsolete/` for an entry covering this
interface.

- If an entry exists, record its stability tier and any listed
  Users.
- If no entry exists, record "undocumented."

### 2b: Determine interface age

Use `git log` to find when the interface was introduced. An
interface that has existed across multiple kernel releases has
higher implicit stability expectations than one introduced in
the current development cycle.

### 2c: Identify known consumers

Userspace tools that commonly consume each kind of interface:
- For NFS interfaces: nfs-utils, nfsstat, mountstats
- For network interfaces: iproute2, ethtool
- For block interfaces: util-linux, lvm2
- For general procfs/sysfs: sysstat, procps

Search in this order, and no further:
1. The `Users:` field of any ABI entry found in 2a.
2. Local source trees of the projects above, if present under
   `~/src/`. Grep for the file path or the exact format string.

Do not search the web and do not answer from memory. If step 2
has no local tree to search, record consumers as "not checked (no
local sources)", never "none known". "None known" is allowed only
after both steps came up empty.

### 2d: Risk classification

Assign each change a risk level:

| Risk | Criteria |
|------|----------|
| **None** | Addition of a new interface, any tier. Missing documentation is reported by Task 4, not here. |
| **Low** | Removal, format, semantic, or permission change to an undocumented, debugfs, or tracepoint interface that is <2 releases old, or for which 2c found no consumer |
| **Medium** | Removal, format, semantic, or permission change to an undocumented, debugfs, or tracepoint interface that is >=2 releases old and for which 2c found no consumer; or an additive (non-breaking) format change to a testing-tier interface |
| **High** | Any removal, format, semantic, or permission change that breaks a documented stable, testing, or obsolete interface (removal of a stable or testing interface without first moving it to obsolete/ is always High); or any change to an interface for which 2c found a consumer that parses it |

A change that matches more than one row takes the highest matching
row. Record the criteria that matched, not just the label.

## Task 3: Evaluate Commit Message

Check whether the commit message addresses each interface change
found:

- Does it mention the user-visible effect?
- Does it explain why the change is safe (no known consumers,
  parsers should match on name not position, etc.)?
- For removals: does it describe what replaces the removed
  interface, or why the information is no longer meaningful?

## Task 4: Check for Missing ABI Documentation

For any interface that the patch **adds**, check whether a
corresponding `Documentation/ABI/` entry exists or is created
by the same patch. New interfaces without ABI documentation are
a finding (low severity).

For any interface that the patch **removes**, check whether the
corresponding `Documentation/ABI/` entry is also removed or
moved to `removed/`.

## Output

Report findings grouped by risk level (high first). For each:

```
[RISK] File:line -- interface-type
  Change: what changed
  ABI tier: stable / testing / obsolete / undocumented / debugfs
  Age: kernel version introduced, or approximate date
  Consumers: known consumers, "none known", or "not checked"
  Commit message: addressed / not addressed
  Recommendation: what should be done (if anything)
```

Report every change from Task 1, including None-risk additions,
one line each under a final "No risk" group. If Task 1 found no
user-visible interface changes at all, say so explicitly and list
the detection patterns checked.

End with:

```
ABI CHANGES FOUND: <total = High + Medium + Low + None>
  High risk: <n>
  Medium risk: <n>
  Low risk: <n>
  No risk (additions): <n>
  Of the additions, without ABI documentation: <n>
```
