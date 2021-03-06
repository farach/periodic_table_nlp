# Background

## In the beginning…

In natural language processing (NLP) we want to process natural language
as the name implies. So what do we mean by “process”? To process
language is to perform a series of operations to change or analyze
language.

Technically we can process language without computers but generally this
processing we want to do is done with computers because of the
efficiency they provide.

Computers don’t speak the same language as us humans do. That means if
we want to use computers to process language we need some way to encode
language so that computers understand and some way to decode computer
processed language so that we humans can understand.

Both the encoding and decoding process need to be identical on both ends
or the human-to-computer and computer-to-human translation falls apart.
The agreed upon method is called a protocol.

## How to describe the letter “A”?

How would you describe the letter “A” to a computer? It’s difficult.
Instead of going that route we could use numbers to represent letters.
So instead of “A” we would have 1. “B” could be 2 and so on. We can
assign a number to represent each unique character we want to
communicate. We can also use numbers to represent symbols and
punctuation.

Computers store numbers in binary. All signals inside a computer have
only 2 possible values: 0 and 1 (off/on, FALSE/TRUE). Each of these
single 0/1 pieces of information are called bits. A bit represents a
value of 0 or 1. You can use 1 bit to represent 2 values (0 and 1). You
can use 2 bits to represent 4 values, 3 bits to represent 8 values, so
on and so forth.

So how many bits is 256? Using the logic above it’s 8 bits: 2 (1 bit), 4
(2 bits), 8 (3 bits), 16 (4 bits), 32 (5 bits), 64 (6 bits), 128 (7
bits), 256 (**8 bits**).

When the first computers came on to the scene developers decided that a
byte was the next standard unit above a bit. A byte is defined as 8-bits
which can represent 256 different values.

From here we get the megabyte which is 1000000 bytes, the gigabyte
which is 1000 megabytes and so on.

# ASCII, Latin1, and Unicode

In the 1960’s computer developers had 1 byte to work with. They needed
to develop a protocol that fit into this 1 byte (8 bits, 256 possible
values). The protocol they came up with is called ASCII. This protocol
is able to assign a unique number to all letters in the English
language, plus numbers, symbols, and [control
characters](https://en.wikipedia.org/wiki/Control_character).

Everything fit in the 1 byte (256 possible values) budget! Even better,
only 7 (128 possible values) of the available 8 (256 possible values)
bits were needed!

Over time the need to fit more and more information on bits grew larger.
Luckily we had that extra bit to play with with. Things eventually got
standardized into what is known as Latin1 or the ISO-8859-1 standard
which uses the full 8 bits available in the single byte. The issue with
this protocol is that it only included English language letters - ergo
the name, Latin1.

A new standard had to be developed, enter Unicode (or UTF-8 which stands
for **8** bit **U**nicode **t**ransformation **f**ormat). Unicode uses
multiple bytes to represent thousands of symbols from languages all over
the world. Common characters are stored with fewer bits and less common
stuff requires a little bit more.

The web is standardized on the Unicode format. This format is backwards
compatible with ASCII and Latin1. Each character in UTF-8 is represented
using a prefix U and followed by a 4 digit hexadecimal number. 4
hexadecimal numbers requires 2 bytes to store them (or 16 bits), so with
just 2 bytes over 65,000 symbols can be encoded and decoded! The entire
breadth of Unicode can store 1,114,112 symbols called code points -
clearly enough to capture all the letters, symbols, numbers, and even
emojis!

There is a limit though so stuff shouldn’t be added all willy nilly.
This is why emojis take a while to appear on your phone’s keyboard. A
[group of people called the Unicode
Consortium](https://en.wikipedia.org/wiki/Unicode_Consortium) need to
debate whether or not 1 code point of whats left of the 1,114,112 total
is worth assigning to whatever new emoji they are discussing.

One last note before we move on, there are more character encoding
protocols than the 3 I have discussed thus far, for example, UTF-16 or
UTF-32. As you may have guessed from the “16” and the “32”, these
protocols allow for more and more complicated character representations.

Despite this increased power most systems go with UTF-8 since it is
backwards compatible with ASCII. If you would like to see a full list of
encoding that are supported by
[ICU](https://en.wikipedia.org/wiki/International_Components_for_Unicode)
run the `stri_enc_list()` function that’s part of the `stringi` package
(there are a lot).

``` r
paste("Total number of encodings:", length(stringi::stri_enc_list()))
```

    ## [1] "Total number of encodings: 1203"

Here is a sample of 15 of them.

``` r
sample(stringi::stri_enc_list(), size = 15)
```

    ##  [1] "x-IBM737"           "ibm-1158"          
    ##  [3] "x-utf-16be"         "ibm-1251"          
    ##  [5] "cp1122"             "l8"                
    ##  [7] "866"                "ibm-954_P101-2007" 
    ##  [9] "IBM861"             "ibm-1204"          
    ## [11] "ibm-61956"          "ebcdic-no-277+euro"
    ## [13] "ibm-5471_P100-2006" "IBM285"            
    ## [15] "ibm-367"

# Character string encoding in R

Character strings in R can be declared to be encoded in latin1, UTF-8,
or as bytes. These declarations can be read or changed using the
[`Encoding()`
function](https://stat.ethz.ch/R-manual/R-devel/library/base/html/Encoding.html).

Let’s take a look at the word “café” which is Spanish for coffee. We can
write it in different ways which will give us different detected
encodings.

``` r
print(c("coffee", "café", "caf\u00E9", "caf\xe9"))
```

    ## [1] "coffee" "café"   "café"   "café"

``` r
Encoding(c("coffee", "café", "caf\u00E9", "caf\xe9"))
```

    ## [1] "unknown" "latin1"  "UTF-8"   "latin1"

What’s peculiar here is that “coffee” is showing up as unknown. “coffee”
is a very basic string containing English letters which are all part of
ASCII and latin1. So what’s going on?

Turns out that ASCII strings will never be marked with a declared
encoding, since their representation is the same in all supported
encodings.

Let’s keep going with the other ones. In the list above we saw that
“caf\\xe9” was being declared as latin1. We can change that to Unicode.

``` r
x <- "caf\xe9"

Encoding(x) <- "UTF-8"

Encoding(x)
```

    ## [1] "UTF-8"

Let’s try and change “caf\\u00E9” to latin1.

``` r
x <- "caf\u00E9"

Encoding(x) <- "latin1"

Encoding(x)
```

    ## [1] "latin1"

So far so good. What about “café”? Why did it get declared as “latin1”
in the list above and not “UTF-8”?

This is not because systems always go to the oldest compatible encoding
system. What it does is use what’s known as the “native encoding” to
assign an encoding. Natively encoded strings are strings written in
whatever code page the user is using. On linux and macOS the native
encoding is UTF-8 so all Unicode characters are supported. On Windows,
the native encoding cannot be UTF-8 nor any other that could represent
all Unicode characters (\*sad trombone sound here\*). This limitation of
R on Windows is a source of pain that you can read all about
[here](https://developer.r-project.org/Blog/public/2020/05/02/utf-8-support-on-windows/#:~:text=R%20internally%20allows%20strings%20to,be%20converted%20to%20native%20encoding.).

To see what is your native encoding in R you can use the
[`Sys.getlocale()`
function](https://stat.ethz.ch/R-manual/R-devel/library/base/html/locales.html).

``` r
Sys.getlocale()
```

    ## [1] "LC_COLLATE=English_United States.1252;LC_CTYPE=English_United States.1252;LC_MONETARY=English_United States.1252;LC_NUMERIC=C;LC_TIME=English_United States.1252"

We can clean this up a little for it to make more sense.

``` r
localeCategories <- c("LC_COLLATE","LC_CTYPE","LC_MONETARY","LC_NUMERIC","LC_TIME")
locales <- setNames(sapply(localeCategories, Sys.getlocale), localeCategories)

locales
```

    ##                   LC_COLLATE                     LC_CTYPE 
    ## "English_United States.1252" "English_United States.1252" 
    ##                  LC_MONETARY                   LC_NUMERIC 
    ## "English_United States.1252"                          "C" 
    ##                      LC_TIME 
    ## "English_United States.1252"

The function [`l10n_info()`
function](https://stat.ethz.ch/R-manual/R-devel/library/base/html/l10n_info.html)
tells us the localization info by returning a list with three logical
and one integer components:

-   `MBCS`: if a multi-byte character set in use?

-   `UTF-8`: Is this a UTF-8 locale?

-   `Latin-1`: Is this a Latin-1 locale?

-   `codepage`: the Windows codepage corresponding to the locale R is
    using (and not necessarily that Windows is using).

-   `system.codepage`: integer: the Windows system/ANSI codepage (the
    codepage Windows is using). Added in **R** 4.1.0.

If I happened to not be on the I wouldn’t see the `codepage` and
`system.codepage` element and in there place I would see

-   `codeset`: character. The encoding name as reported by the OS,
    possibly "". (Added in R 4.1.0. Encoding names are OS-specific.)

``` r
l10n_info()
```

    ## $MBCS
    ## [1] FALSE
    ## 
    ## $`UTF-8`
    ## [1] FALSE
    ## 
    ## $`Latin-1`
    ## [1] TRUE
    ## 
    ## $codepage
    ## [1] 1252
    ## 
    ## $system.codepage
    ## [1] 1252

Here we see why “café” was declared as “latin1” and not“UTF-8”! I am
using Windows with codepage 1252 (Western European).

Let’s confirm.

``` r
Sys.info()[1:5]
```

    ##          sysname          release          version 
    ##        "Windows"         "10 x64"    "build 19042" 
    ##         nodename          machine 
    ## "AFSWWTSL0PDDKF"         "x86-64"

Let’s revisit “café” and convert it. Instead of doing it like we have
above we can use the
[`iconv()`](https://stat.ethz.ch/R-manual/R-devel/library/base/html/iconv.html)
function. This function uses system facilities to convert a character
vector between encodings: the “i” stands for “internationaliation”.

``` r
x <- "café"
Encoding(x)
```

    ## [1] "latin1"

``` r
x <- iconv(x, from = Encoding(x), to = "UTF-8")
Encoding(x)
```

    ## [1] "UTF-8"

We can have a bit more fun by looking at the raw bytes by using the
[`rawToChar`
function](https://stat.ethz.ch/R-manual/R-devel/library/base/html/rawConversion.html).
Notice the e accent is not a regular number?

``` r
x <- "café"
charToRaw(x)
```

    ## [1] 63 61 66 e9

# Character encoding, Tidyverse style

I enjoy working in the tidyverse so I thought it would be helpful to
look at character encoding from a tidyverse perspective.

The string manipulation workhorse in the tidyverse is the [`stringr`
package](https://stringr.tidyverse.org). We can specify the encoding of
a string with the [`str_conv()`
function](https://stringr.tidyverse.org/reference/str_conv.html).

``` r
suppressMessages(suppressWarnings(library(tidyverse)))

str_conv(string = "café", encoding = "latin1")
```

    ## [1] "café"

``` r
str_conv(string = "café", encoding = "UTF-8")
```

    ## [1] "caf<U+FFFD>"

``` r
str_conv(string = "café", encoding = sample(stringi::stri_enc_list(), 1))
```

    ## [1] "caf\032"

The world of character encoding goes much deeper than this and even
farther down as you look into how R handles it. That being said, this
should be a good start for those looking to get a good understanding of
the implications for NLP.

Please feel free to reach out if any of this information could be
cleaned up or is flat out wrong. This information is not covered in
Hadley’s Advanced R unfortunately so I had to put it together piecemeal
myself using the links I’ve attached in the document and the information
in the references below.

# References

[Encoding character strings in
R](https://rstudio-pubs-static.s3.amazonaws.com/279354_f552c4c41852439f910ad620763960b6.html)

[ISO-8859-1 (ISO Latin 1) Character
Encoding](https://www.ic.unicamp.br/~stolfi/EXPORT/www/ISO-8859-1-Encoding.html)

[ASCII Characters for MPE
Users](www.robelle.com/library/smugbook/ascii.html)

[The Absolute Minimum Every Software Developer Absolutely, Positively
Must Know About Unicode and Character Sets (No
Excuses!)](https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/)

[The Story of
256](https://256stuff.com/256.html#:~:text=A%20byte%20is%20defined%20as,byte%20represents%20256%20different%20values.&text=So%20that's%20it.,different%20values%3A%200%20to%20255)

[Character
Encoding](https://en.wikipedia.org/wiki/Character_encoding#:~:text=Simple%20character%20encoding%20schemes%20include,number%20of%20bytes%20used%20per)
