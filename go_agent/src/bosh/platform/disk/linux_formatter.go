package disk

import (
	boshsys "bosh/system"
	"fmt"
	"strings"
)

type linuxFormatter struct {
	runner boshsys.CmdRunner
	fs     boshsys.FileSystem
}

func newLinuxFormatter(runner boshsys.CmdRunner, fs boshsys.FileSystem) (formatter linuxFormatter) {
	formatter.runner = runner
	formatter.fs = fs
	return
}

func (f linuxFormatter) Format(partitionPath string, fsType FileSystemType) (err error) {
	if f.partitionHasGivenType(partitionPath, fsType) {
		return
	}

	switch fsType {
	case FileSystemSwap:
		_, _, err = f.runner.RunCommand("mkswap", partitionPath)
	case FileSystemExt4:
		if f.fs.FileExists("/sys/fs/ext4/features/lazy_itable_init") {
			_, _, err = f.runner.RunCommand("mke2fs", "-t", "ext4", "-j", "-E", "lazy_itable_init=1", partitionPath)
		} else {
			_, _, err = f.runner.RunCommand("mke2fs", "-t", "ext4", "-j", partitionPath)
		}
	}
	return
}

func (f linuxFormatter) partitionHasGivenType(partitionPath string, fsType FileSystemType) bool {
	stdout, _, err := f.runner.RunCommand("blkid", "-p", partitionPath)
	if err != nil {
		return false
	}

	return strings.Contains(stdout, fmt.Sprintf(` TYPE="%s"`, fsType))
}
