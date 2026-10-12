// Package version reports what this build is.
//
// It exists so that a new project has one real package with one real test
// from its first commit: the coverage floor and the "no tests ran" guard
// then measure something from day one instead of being switched on later.
// Replace it with the first real package; keep the property.
package version

// Version is set at link time with -ldflags "-X <module>/internal/version.Version=v1.2.3".
// The zero-configuration value says so rather than pretending to a release.
var Version = "0.0.0-dev"

// String is the one-line identification a binary prints for -version.
func String(program string) string {
	return program + " " + Version
}
