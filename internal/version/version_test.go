package version

import "testing"

func TestString_NamesTheProgramAndTheVersion(t *testing.T) {
	old := Version
	t.Cleanup(func() { Version = old })
	Version = "v1.2.3"

	if got, want := String("example"), "example v1.2.3"; got != want {
		t.Fatalf("String() = %q, want %q", got, want)
	}
}

func TestVersion_TheDefaultSaysItIsNotARelease(t *testing.T) {
	if Version != "0.0.0-dev" {
		t.Fatalf("an unlinked build must report 0.0.0-dev, got %q", Version)
	}
}
