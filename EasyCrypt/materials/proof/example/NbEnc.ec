(* Syntax and security for Nonce-based Symmetric Encryption *)

require import AllCore Distr List.
require import QCounter.

theory NbEnc.

(* Types for algorithm inputs and outputs *)
type key.
type nonce.
type plaintext.
type ciphertext.

(* The ideal scheme samples ciphertexts uniformly at random.  *)
op dciphertext : ciphertext distr.
axiom dciphertext_ll : is_lossless dciphertext.
axiom dciphertext_uni : is_uniform dciphertext.
axiom dciphertext_full : is_full dciphertext.

(* Syntax and correctness *)
module type Scheme_T = {
  proc kg () : key
  proc enc(k:key, n:nonce, p:plaintext) : ciphertext
  proc dec(k:key, n:nonce, c:ciphertext) : plaintext
}.

module Correctness(Scheme : Scheme_T) = {
   proc main(k : key, n : nonce, p : plaintext) : bool = {
      var c,p';
      c <@ Scheme.enc(k,n,p);
      p' <@ Scheme.dec(k,n,c);
      return p' = p;
   }
}.

(* Security *)

(* The adversarial oracle interface *)
module type OrclCPA = {
  proc enc(n:nonce, p:plaintext) : ciphertext
}.

(* Extension to allow main game to initialize oracles *)
module type OrclCPAi = {
  proc init() : unit
  include OrclCPA
}.

(* The type of adversaries *)
module type AdvCPA (O:OrclCPA) = {
   proc main() : bool
}.

(* The real-world oracle uses a concrete scheme *)
module RealScheme(Scheme : Scheme_T) : OrclCPAi = {
  var k : key

  proc init() = {
    QCounter.init();
    k <@ Scheme.kg();
  }

  proc enc(n:nonce, p:plaintext) = {
    var c;
    QCounter.count();
    c <@ Scheme.enc(k,n,p);
    return c;
  }
}.

(* The ideal-world scheme samples uniform ciphertexts *)
module IdealScheme : OrclCPAi = {
  proc init() = {
    QCounter.init();
  }

  proc enc(n:nonce, p:plaintext) = {
    var r;
    QCounter.count();
    r <$ dciphertext;
    return r;
  }
}.

(* The security game only calls oracles if nonces do not
   repeat. It is parametrised by one of the real or ideal
   schemes.  *)
module CPA(A:AdvCPA) (O:OrclCPAi) = {
  var nonces : nonce list

  module WO : OrclCPA = {
    proc enc(n:nonce, p:plaintext) = {
      var c;
      c <- witness;
      if (!n \in nonces) {
        c <@ O.enc(n,p);
        nonces <- n::nonces;
      }
      return c;
    }
  }

  proc main() = {
    var b;
    nonces <- [];
    O.init();
    b <@ A(WO).main();
    return b;
  }
}.

(* In this case advantage is of the form

`| Pr[CPA(A,RealScheme(Scheme)).main() @ &m : res ] - 
              Pr[CPA(A,IdealScheme).main() @ &m : res ]|

*)

end NbEnc.
