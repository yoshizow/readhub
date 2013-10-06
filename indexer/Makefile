all: bin/checkout-and-index-wrapper

bin/checkout-and-index-wrapper: src/checkout-and-index-wrapper.c
	gcc -o $@ $<

install: bin/checkout-and-index-wrapper
	install -m 755 -o root -g root bin/checkout-and-index /usr/local/bin/
	install -m 6755 -o www-data -g www-data -s bin/checkout-and-index-wrapper /usr/local/bin/

clean:
	rm -f bin/checkout-and-index-wrapper
