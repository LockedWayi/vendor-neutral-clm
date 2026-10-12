// Command vendor-neutral-clm is the entry point. It parses flags, wires
// dependencies and calls into internal/; logic worth testing lives there.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/LockedWayi/vendor-neutral-clm/internal/version"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

// run is main without the process: tests call it with their own arguments
// and writers, so the CLI is tested through its own entry point.
func run(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("vendor-neutral-clm", flag.ContinueOnError)
	fs.SetOutput(stderr)
	showVersion := fs.Bool("version", false, "print the version and exit")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *showVersion {
		_, _ = fmt.Fprintln(stdout, version.String("vendor-neutral-clm"))
		return 0
	}
	// Nothing to do yet is a refusal, not a silent success.
	_, _ = fmt.Fprintln(stderr, "vendor-neutral-clm: nothing to do yet; see docs/phases/")
	return 1
}
