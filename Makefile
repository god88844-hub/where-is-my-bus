FLUTTER ?= flutter

.PHONY: doctor bootstrap run-android analyze test apk-debug clean

doctor:
	$(FLUTTER) doctor -v

bootstrap:
	$(FLUTTER) pub get

run-android:
	$(FLUTTER) run

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

apk-debug:
	$(FLUTTER) build apk --debug

clean:
	$(FLUTTER) clean
