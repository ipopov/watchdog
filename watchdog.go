package main

import "io/ioutil"
import "log"
import "net/http"
import "os"
import "os/signal"
import "strings"
import "time"

import wdt "github.com/digineo/go-watchdogtimer"

func poll() (bool, error) {
	resp, err := http.Get("http://type.ivo.party/watchdog")
	if err != nil {
		return false, err
	}
	r, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return false, err
	}
	return strings.Contains(string(r), "ok"), nil
}

func main() {
	// In case the whole implementation is badly broken, give
	// ourselves a period of liveness after boot. This should be
	// sufficient to ssh in and disable the service.
	log.Print("Sleeping for 15 minutes.")
	lastOk := time.Now()
	time.Sleep(15 * time.Minute)

	w, err := wdt.Open("/dev/watchdog0")
	if err != nil {
		log.Fatal(err)
	}
	to, _ := w.GetTimeout()
	log.Print("Opened watchdog; timeout is ", to)

	// For interactive testing of the program: handle Ctrl+C.
	ctrlc := make(chan os.Signal, 1)
	signal.Notify(ctrlc, os.Interrupt)

	for {
		if time.Since(lastOk) < (5 * time.Minute) {
			_ = w.Pat()
		} else {
			ok, _ := poll()
			if ok {
				lastOk = time.Now()
				log.Print("Canary OK")
				_ = w.Pat()
			} else {
				log.Print("Canary not OK")
			}
		}
		select {
		case <-ctrlc:
			goto End
		case <-time.After(2 * time.Second):
		}
	}
End:

	log.Print("Disabling watchdog")
	_ = w.Disable()
}
