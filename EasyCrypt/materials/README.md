## EasyCrypt and Jasmin Tutorial

This is the helper material for the tutorial on EasyCrypt and Jasmin  Indocrypt 2020 .

Contributors: Manuel Barbosa, François Dupressoir, Benjamin Grégoire, Vincent Laporte, Pierre-Yves Strub

## Documentation

- `doc/slides.pdf` contains the presentation which explains the example and exercises
- `doc/cheatsheet.pdf` contains a new EasyCrypt cheat sheet


## Jasmin Files

- `src/example/NbAESEnc.jazz` is a Jasmin implementation of AES-based NbPRFEnc with register-based calling convention
- `src/example/NbAESEnc_mem.jazz` is a Jasmin implementation of AES-based NbPRFEnc with memory-based calling convention
- `src/aeslib/aes.jazz` is reusable code for AES-NI in Jasmin

## EasyCrypt Files

Folder `proof/example` contains the EasyCrypt specs and proofs for the example:

- `.dir-locals.el`: Emacs EasyCrypt mode configuration file to extend include path
- `QCounter.ec`: Simple counter to keep track of queries
- `RFth.eca`: formalization of a random function
- `RPth.eca`: formalization of a random permutation
- `PRFth.eca`: formalization of pseudorandom function
- `PRPth.eca`: formalization of pseudorandom permutation and RF/RP switching lemma
- `NbEnc.ec`: formalization of syntax, correctness and security of nonce-based encryption
- `NbPRFEnc.ec`: nonce-based encryption from a PRF (the main example)
- `NbAESEnc_proof.ec`: Correctness and security proof for Jasmin implementation with register calling convention wrt to `NbPRFEnc.ec`
- `NbAESEnc_ct_proof.ec`: Constant-time proof for Jasmin implementation with register calling convention
- `NbAESEnc_mem_proof.ec`: Correctness proof for Jasmin implementation with memory calling convention wrt to `NbPRFEnc.ec`
- `NbAESEnc_mem_ct_proof.ec`: Constant-time proof for Jasmin implementation with memory calling convention

Folder `proof/aeslib` contains the EasyCrypt specs and proofs for AES-NI:

- `.dir-locals.el`: Emacs EasyCrypt mode configuration file to extend include path
- `AES_spec.ec`: AES specification in both functional and imperative style, equivalence between the two
- `AES_proof.ec`: Correctness proof for Jasmin implementation of AES wrt to `AES_spec.ec`
- `AES_ct_proof.ec`: Constant-time proof for Jasmin implementation of AES

Folder `extraction` contains the EasyCrypt code that is automatically generated from the Jasmin souces (the correctness and constant-time proofs then import these files):

- `extraction/example/NbAESEnc_jazz.ec`: EasyCrypt code extracted from `src/example/NbAESEnc.jazz`
- `extraction/example/NbAESEnc_jazz_ct.ec`: EasyCrypt code extracted from `src/example/NbAESEnc.jazz` for constant-time proof
- `extraction/example/NbAESEnc_mem_jazz.ec`: EasyCrypt code extracted from `src/example/NbAESEnc.jazz`
- `extraction/example/NbAESEnc_mem_jazz_ct.ec`: EasyCrypt code extracted from `src/example/NbAESEnc.jazz` for constant-time proof
- `extraction/aeslib/AES_jazz.ec`: EasyCrypt code extracted from `src/aeslib/aes.jazz`
- `extraction/aeslib/AES_jazz_ct.ec`: EasyCrypt code extracted from `src/aeslib/aes.jazz` for constant-time proof
- Additional files generated by the Jasmin compilers for array types also appear in this folder.

Folder `test` contains the wrapper C files for executing the Jasmin examples:

- `test_NbAESEnc.c`: C program to test `NbAESEnc.s` generated from `src/example/NbAESEnc.jazz`
- `test_NbAESEnc_mem.c`: C program to test `NbAESEnc_mem.s` generated from `src/example/NbAESEnc_mem.jazz`
- `test_aes.c`: C program to test `aes.s` generated from `src/aeslib/aes.jazz`

## How-to

Make sure to edit the Makefile so that it can find `easycrypt` and `jasminc`.

Then, from root directory:

- `make clean` removes olds files
- `make all` builds tests and extracts EasyCrypt code
- `make safety` checks Jasmin code for safety
- `make test` executes the tests
- `make proofs` uses EasyCrypt to check all proofs
- `make check` runs `safety`, `test` and `proofs` in one go

