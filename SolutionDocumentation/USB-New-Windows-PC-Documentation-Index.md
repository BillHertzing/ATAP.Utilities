# USB and New Windows PC Setup Documentation Index

This index records documentation found in the Sprint 0015 worktrees for
`ATAP.Utilities` and `ATAP.IAC` that discusses setting up a new computer,
creating or using USB media, or preparing Windows installation media. Line
numbers refer to the files as inspected on 2026-09-06.

## Most useful Windows/USB setup instructions

### ATAP.Utilities — canonical new-computer runbook

File: `SolutionDocumentation/NewComputerSetup.md`

- **§ OS Image Sources, lines 77–96:** distinguishes a Microsoft OEM image from
  a custom organization image maintained in `ATAP.IAC`; states that the
  dedicated custom Windows 11 image explainer is not yet written.
- **§ Step 0, lines 98–191:** prepares a MemTest86 bootable USB, including
  download, `imageUSB.exe`, USB size/destructive-write warning, disk
  identification, UEFI boot, Secure Boot fallback, test passes, and saving the
  report back to the stick. This is hardware-validation media, not Windows
  installation media.
- **§ Step 1, lines 193 onward:** begins Windows installation and machine
  identity setup, but does not give a Rufus-based Windows USB creation recipe.

This is the maintained/canonical new-computer document. Its opening note says
the companion Ansible document is retained for deeper BIOS, OS-install, and
Ansible-bootstrap notes.

### ATAP.Utilities — legacy/deeper Windows USB and Ansible bootstrap runbook

File: `SolutionDocumentation/NewComputerSetupUsingAnsible.md`

- **§ Introduction and Presetup steps, lines 31–43:** frames the document as
  bootstrapping a new Windows host and explicitly calls for creating a bootable
  USB with Rufus; the first-user setup is marked “details TBD.”
- **§ BIOS modifications, lines 45–60:** selects the USB drive as the UEFI boot
  option and records machine-specific BIOS preparation.
- **§ Install the Operating system, lines 62–78:** directly describes Windows
  installation from an ISO on a USB stick: create the stick from an ISO with
  Rufus, use Rufus to create a local user/bypass Microsoft-account login, boot
  from the stick, install to the M.2 SSD, then remove the stick and change boot
  order after reboot.
- **§ Bootstrap a new host accepting communications from Ansible, lines
  116–137:** recommends downloading and malware-checking
  `ConfigureRemotingForAnsible.ps1`, then transferring it via USB as a safer
  alternative to downloading directly on the new PC.
- **§ New-computer post-install notes, lines 219–254:** includes running
  Everything from a USB stick to capture clean-install file lists and a TBD
  note about installing Python 3.11 from USB.

The file itself says it is retained for these deeper notes and that
`NewComputerSetup.md` takes precedence where the two overlap.

### ATAP.Utilities — IAC package README

File: `src/ATAP.Utilities.IAC.Ansible.Powershell/ReadMe.md`

- **§ Hardware Level setup for a new computer → Windows Operating System
  Prerequisites setup, lines 504–509:** says to create the latest Windows 11
  bootable USB with Rufus, select a local account named `FirstAdmin`, and have
  the Windows 11 Pro license key ready.
- **§ clean-install inventory steps, lines 530 and 546:** says to run
  Everything from the USB stick and save “01 Clean Windows 11 install, Step 01
  Files.efu” and “Step 02 Files.efu.”
- **§ Install hosts to new computer, lines 555–556:** describes copying the
  hosts file to the new computer; this is a follow-on step rather than USB
  creation guidance.

## Supporting IAC design/reference files

### ATAP.Utilities — organization-infrastructure design draft

File: `src/ATAP.Utilities.IAC.Ansible.Powershell/Documentation/Starting an organization infrastructure.md`

- **§ Architecture for the initialization of a new computer, lines 5–8:**
  establishes the new-computer/IAC bootstrap context; details are explicitly
  marked TBD.
- **§ Boot Setup Image, lines 17–37:** identifies Windows source ISO, ISO
  modifications, debloating, custom `autoUnattend.xml`, NTLite, and creation
  of a bootable USB using Rufus.
- **§ Validation of boot setup image and Preamble, lines 39–84:** lists the
  expected post-boot Windows/Ansible baseline, including log locations,
  PowerShell installation, certificates, and profiles.

### ATAP.IAC — custom boot-stick link collection

File: `Documentation/linksForCustomBootStick.txt`

- **Lines 2–4, 8–19:** links to unattended Windows/OOBE, NTLite, package and
  post-install resources, including `UnattendedWinInstall`, custom ISO trees,
  and `autounattend.xml`.
- **Lines 21–29:** links to Microsoft unattended-setup documentation, Windows
  Setup installation-process documentation, driver resources, and the Rufus
  site at line 29.
- **Lines 30–45:** additional driver, Windows customization, unattended-media,
  and Windows ISO references.

This is a reference list, not a step-by-step procedure.

### ATAP.IAC — exported browser bookmarks for custom boot ISO

File: `Documentation/exported chrome bookmarks for custom boot ISO bookmarks_8_30_24.html`

- **Lines 4, 19–22, 54–55, and 76–88:** bookmarked Microsoft Windows Setup,
  unattended-setup, and Windows installation-process pages, plus an
  unattended-media article.
- **Lines 25, 57, 67, and 78:** bookmarked Rufus and/or custom
  `autounattend.xml` resources.

The HTML is an exported bookmark artifact; it contains links rather than local
instructions.

### ATAP.IAC — bootstrap inventory and identity decision

Files:

- `Documentation/Ncat040-Bootstrap-Inventory.md`
  - **§ Remaining acceptance criteria, lines 36–59:** states that USB-media
    rebuild is part of the administrator-identity decision and that USB-media
    disposition was not verified.
  - **§ Assertions and non-claims, lines 61–76:** says USB handling and media
    disposition were not performed.
- `Documentation/Ncat040-Administrator-Identity-Decision.md`
  - **§ Purpose and decision status, lines 1–15:** says the ncat040 bootstrap
    USB media was not inspected, mounted, rebuilt, or used.
  - **§ Required human decision, lines 35–45:** requires an explicit human
    choice on whether to rebuild the USB media and lists identity-bound reasons
    that would require rebuilding.
  - **§ Impact assessment, lines 47–57:** analyzes USB-media implications for
    retaining, renaming, or replacing the administrator account.
  - **§ Information required before approval, lines 65–70:** requires a
    metadata-only inspection of the USB manifest and bootstrap scripts.

These files concern safe disposition of existing bootstrap media, not creation
of a new Windows installation stick.

## Search boundary and exclusions

The search covered Markdown, HTML, TXT, PowerShell, and module files in both
Sprint 0015 worktrees. It found incidental USB comments in implementation
files, such as `ATAP.IAC/Windows/HostSettings.ps1:403` and
`ATAP.Utilities/src/ATAP.Utilities.PowerShell/Profiles/global_SecurityAndSecretsSettings.ps1:74`;
these are TODO comments, not setup documentation, and are excluded from the
main index. Similarly, generic “new computer” references in Ansible role code
were excluded unless they described the USB/Windows bootstrap workflow.

## Practical reading order

1. Read `SolutionDocumentation/NewComputerSetup.md` for the current canonical
   workstation flow and its MemTest86 USB prerequisite.
2. Read `SolutionDocumentation/NewComputerSetupUsingAnsible.md` for the
   detailed Rufus/Windows ISO boot and Ansible bootstrap procedure.
3. Read `src/ATAP.Utilities.IAC.Ansible.Powershell/ReadMe.md` for the older
   concrete Windows 11/Rufus checklist and clean-install inventory steps.
4. Read `Starting an organization infrastructure.md`, then the two ATAP.IAC
   link/bookmark files, for the custom-ISO/`autoUnattend.xml` design direction
   and external references.
5. Consult the ncat040 files only when deciding whether existing bootstrap
   media may safely be reused or must be inspected/rebuilt.
