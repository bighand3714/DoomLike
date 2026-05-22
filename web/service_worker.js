const CACHE_NAME = "doomlike-v0.1.0";
const CACHE_FILES = [
	"index.html",
	"index.js",
	"index.wasm",
	"index.pck",
	"index.audio.worklet.js",
	"manifest.json"
];

self.addEventListener("install", function(event) {
	event.waitUntil(
		caches.open(CACHE_NAME).then(function(cache) {
			return cache.addAll(CACHE_FILES);
		})
	);
});

self.addEventListener("activate", function(event) {
	event.waitUntil(
		caches.keys().then(function(keys) {
			return Promise.all(
				keys.filter(function(key) { return key !== CACHE_NAME; })
					.map(function(key) { return caches.delete(key); })
			);
		})
	);
});

self.addEventListener("fetch", function(event) {
	event.respondWith(
		caches.match(event.request).then(function(response) {
			return response || fetch(event.request);
		})
	);
});
