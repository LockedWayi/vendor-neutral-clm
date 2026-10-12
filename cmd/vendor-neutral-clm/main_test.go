package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRun_VersionPrintsAndSucceeds(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run([]string{"-version"}, &out, &errOut); code != 0 {
		t.Fatalf("exit %d, stderr %q", code, errOut.String())
	}
	if !strings.HasPrefix(out.String(), "vendor-neutral-clm ") {
		t.Fatalf("stdout %q does not name the program", out.String())
	}
}

func TestRun_NoArgumentsRefuses(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run(nil, &out, &errOut); code != 1 {
		t.Fatalf("exit %d, want 1", code)
	}
	if errOut.Len() == 0 {
		t.Fatal("a refusal must say why")
	}
}

func TestRun_AnUnknownFlagIsAUsageError(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run([]string{"-no-such-flag"}, &out, &errOut); code != 2 {
		t.Fatalf("exit %d, want 2", code)
	}
}
