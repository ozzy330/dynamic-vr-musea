package main

import (
	"crypto/sha256"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

// ── /world ─────────────────────────────────────────────────────────────────────

func TestHandleWorld_Checksum(t *testing.T) {
	want := sha256File(t, filepath.Join("data", "world.json"))

	req := httptest.NewRequest(http.MethodGet, "/world", nil)
	rr := httptest.NewRecorder()
	handleWorld(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	got := sha256Body(t, rr.Body)
	if want != got {
		t.Fatalf("checksum mismatch:\n  file: %x\n  http: %x", want, got)
	}
}

func TestHandleWorld_MethodNotAllowed(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/world", nil)
	rr := httptest.NewRecorder()
	handleWorld(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected 405, got %d", rr.Code)
	}
}

// ── /media/* ───────────────────────────────────────────────────────────────────

func mediaServer() *httptest.Server {
	mux := http.NewServeMux()
	mediaDir := http.Dir(filepath.Join(".", "media"))
	mux.Handle("/media/", http.StripPrefix("/media/", http.FileServer(mediaDir)))
	return httptest.NewServer(mux)
}

func TestMedia_Checksum(t *testing.T) {
	srv := mediaServer()
	defer srv.Close()

	files := []string{
		"images/gatito.jpg",
		"audio/pop-music-music-loop-sound.ogg",
		"video/nyan.ogv",
	}

	for _, f := range files {
		f := f // capture
		t.Run(f, func(t *testing.T) {
			want := sha256File(t, filepath.Join("media", f))

			resp, err := http.Get(srv.URL + "/media/" + f)
			if err != nil {
				t.Fatalf("GET /media/%s: %v", f, err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Fatalf("expected 200, got %d for %s", resp.StatusCode, f)
			}
			got := sha256Body(t, resp.Body)
			if want != got {
				t.Fatalf("checksum mismatch for %s:\n  file: %x\n  http: %x", f, want, got)
			}
		})
	}
}

func TestMedia_NotFound(t *testing.T) {
	srv := mediaServer()
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/media/no-existe.jpg")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", resp.StatusCode)
	}
}

// ── helpers ────────────────────────────────────────────────────────────────────

func sha256File(t *testing.T, path string) [32]byte {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatalf("open %s: %v", path, err)
	}
	defer f.Close()
	return sha256Reader(t, f)
}

func sha256Body(t *testing.T, r io.Reader) [32]byte {
	t.Helper()
	return sha256Reader(t, r)
}

func sha256Reader(t *testing.T, r io.Reader) [32]byte {
	t.Helper()
	h := sha256.New()
	if _, err := io.Copy(h, r); err != nil {
		t.Fatalf("sha256 read: %v", err)
	}
	var out [32]byte
	copy(out[:], h.Sum(nil))
	return out
}
