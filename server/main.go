package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
)

const port = ":8080"

func main() {
	// GET /world — returns data/world.json as JSON.
	http.HandleFunc("/world", handleWorld)

	// GET /media/* — static file server rooted at the media/ directory.
	// http.FileServer handles path-traversal prevention automatically.
	mediaDir := http.Dir(filepath.Join(".", "media"))
	http.Handle("/media/", http.StripPrefix("/media/", http.FileServer(mediaDir)))

	log.Printf("Museum server listening on %s", port)
	log.Fatal(http.ListenAndServe(port, nil))
}

func handleWorld(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	data, err := os.ReadFile(filepath.Join("data", "world.json"))
	if err != nil {
		if os.IsNotExist(err) {
			http.Error(w, "world.json not found", http.StatusNotFound)
		} else {
			http.Error(w, "failed to read world.json", http.StatusInternalServerError)
		}
		log.Printf("ERROR /world: %v", err)
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}
