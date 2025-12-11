package backuptool

import (
	"bufio"
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"testing"
)

const chunkSize = 64000

// Compare file content
func deepCompare(file1, file2 string) bool {
	f1, err := os.Open(file1)
	if err != nil {
		log.Fatal(err)
	}
	defer f1.Close()

	f2, err := os.Open(file2)
	if err != nil {
		log.Fatal(err)
	}
	defer f2.Close()

	for {
		b1 := make([]byte, chunkSize)
		_, err1 := f1.Read(b1)

		b2 := make([]byte, chunkSize)
		_, err2 := f2.Read(b2)

		if err1 != nil || err2 != nil {
			if err1 == io.EOF && err2 == io.EOF {
				return true
			} else if err1 == io.EOF || err2 == io.EOF {
				return false
			} else {
				log.Fatal(err1, err2)
			}
		}

		if !bytes.Equal(b1, b2) {
			return false
		}
	}
}

func TestGetPasswordFromFile(t *testing.T) {
	testData := []byte("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
	pass, err := GetPasswordFromFile("./testData/testPassword")
	if err != nil {
		t.Errorf("Error in getPasswordFromFile: %v", err)
	}
	if !bytes.Equal(testData, pass) {
		t.Errorf("Should be equal: \ntestData =\n%v\npassFromFile=\n%v", testData, pass)
	}
}

func TestAES(t *testing.T) {
	// Load your secret key from a safe place and reuse it across multiple
	// NewCipher calls. (Obviously don't use this example key for anything
	// real.) If you want to convert a passphrase to a key, use a suitable
	// package like bcrypt or scrypt.
	key, _ := hex.DecodeString("6368616e676520746869732070617373")
	plaintext := []byte("exampleplaintextexampleplaintext")

	// CBC mode works on blocks so plaintexts may need to be padded to the
	// next whole block. For an example of such padding, see
	// https://tools.ietf.org/html/rfc5246#section-6.2.3.2. Here we'll
	// assume that the plaintext is already of the correct length.
	if len(plaintext)%aes.BlockSize != 0 {
		panic("plaintext is not a multiple of the block size")
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}

	// The IV needs to be unique, but not secure. Therefore it's common to
	// include it at the beginning of the ciphertext.
	ciphertext := make([]byte, aes.BlockSize+len(plaintext))
	iv := ciphertext[:aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		panic(err)
	}

	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(ciphertext[aes.BlockSize:], plaintext)

	// It's important to remember that ciphertexts must be authenticated
	// (i.e. by using crypto/hmac) as well as being encrypted in order to
	// be secure.

	block2, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}
	mode2 := cipher.NewCBCEncrypter(block2, iv)
	mode2.CryptBlocks(ciphertext[aes.BlockSize:], plaintext[:aes.BlockSize])
	mode2.CryptBlocks(ciphertext[aes.BlockSize+aes.BlockSize:], plaintext[aes.BlockSize:])
}

func TestDecryptFile(t *testing.T) {
	/*
		Test vector genere avec:

			#!/bin/bash
			touch generatedPassword.txt
			for i in $(seq 0 1000); do
							pass=$(openssl rand -base64 256 | tr -d '\n') # >> generatedPassword.txt
							echo "$pass" >> generatedPassword.txt
							openssl rand -base64 $(( $i*100 )) > plain_$i.txt
							openssl aes-256-cbc -pbkdf2 -iter 100000 -k $pass -in plain_$i.txt -out plain_$i.txt.enc
							#echo "\n" >> generatedPassword.txt
			done
	*/
	fPassword, err := os.Open("testData/testVector/generatedPassword.txt")
	if err != nil {
		t.Errorf("Error during password file opening")
	}

	scan := bufio.NewScanner(fPassword)
	i := 0
	for scan.Scan() {
		lign := scan.Text()

		DecryptFile(fmt.Sprintf("testData/testVector/plain_%d.txt.enc", i), fmt.Sprintf("testData/testVector/plain_%d.txt.new", i), []byte(lign))
		if !deepCompare(fmt.Sprintf("testData/testVector/plain_%d.txt", i), fmt.Sprintf("testData/testVector/plain_%d.txt.new", i)) {
			t.Errorf("Decrypted is not equal to plaintext for file: %d", i)
		}
		err = os.Remove(fmt.Sprintf("testData/testVector/plain_%d.txt.new", i))
		if err != nil {
			t.Errorf("Error during cleaning file %d", i)
		}
		i += 1
	}

	/*pass := []byte("eLPXiSzztQZPMOR6HGdmKd6c3B1+47+qe7wz6DE3Wsw4GFw+5hKAYcTr1ub5yBQhT0HgiDaIWwCCrEAjgKZDRTaZsY27izXTBlInBun67nHNqgwqkLeOujPnDtLkgVT6kgMO6wTfZExtuTIczCiiT+R49MIaTKxjTRmbaHZU2jslpwRL1upHvB0d9C/T6zO1tNHKf5sn+5HAy6+ZlMLdzElHBf7OcZJAd+sTNn+mcXJ2y3KDGH/s8YkooV62C2AcYcuXJjkwUAf2PAXQYXaB/DT/0d1QkqzHZmq0DJaSptAJBpcnsix/1sufTJ86bomkM4IEkx40s242A3uHiZwsTw==")
	decryptFile("testData/test.txt.enc", "testData/test2.txt", pass)
	if !deepCompare("testData/test.txt", "testData/test2.txt") {
		t.Errorf("Decrypted is not equal to plaintext")
	}*/
}

func TestEncryptFile(t *testing.T) {
	/*
		Test vector genere avec:

			#!/bin/bash
			touch generatedPassword.txt
			for i in $(seq 0 1000); do
							pass=$(openssl rand -base64 256 | tr -d '\n') # >> generatedPassword.txt
							echo "$pass" >> generatedPassword.txt
							openssl rand -base64 $(( $i*100 )) > plain_$i.txt
							openssl aes-256-cbc -pbkdf2 -iter 100000 -k $pass -in plain_$i.txt -out plain_$i.txt.enc
							#echo "\n" >> generatedPassword.txt
			done
	*/
	fPassword, err := os.Open("testData/testVector/generatedPassword.txt")
	if err != nil {
		t.Errorf("Error during password file opening")
	}

	scan := bufio.NewScanner(fPassword)
	i := 0
	for scan.Scan() {
		lign := scan.Text()
		fGetSalt, err := os.Open(fmt.Sprintf("testData/testVector/plain_%d.txt.enc", i))
		if err != nil {
			t.Errorf("Error during salt retrieval for %d: %v", i, err)
		}
		defer fGetSalt.Close()
		salt := make([]byte, 16)
		_, err = fGetSalt.Read(salt)
		if err != nil {
			t.Errorf("Error during salt reading %d: %v", i, err)
		}

		EncryptFile(fmt.Sprintf("testData/testVector/plain_%d.txt", i), fmt.Sprintf("testData/testVector/plain_%d.txt.enc.new", i), []byte(lign), salt)
		if !deepCompare(fmt.Sprintf("testData/testVector/plain_%d.txt.enc", i), fmt.Sprintf("testData/testVector/plain_%d.txt.enc.new", i)) {
			t.Errorf("Encrypted is not equal to encrypted with openssl for file: %d", i)
		}
		err = os.Remove(fmt.Sprintf("testData/testVector/plain_%d.txt.enc.new", i))
		if err != nil {
			t.Errorf("Error during cleaning file %d", i)
		}
		i += 1
	}

	/*pass := []byte("eLPXiSzztQZPMOR6HGdmKd6c3B1+47+qe7wz6DE3Wsw4GFw+5hKAYcTr1ub5yBQhT0HgiDaIWwCCrEAjgKZDRTaZsY27izXTBlInBun67nHNqgwqkLeOujPnDtLkgVT6kgMO6wTfZExtuTIczCiiT+R49MIaTKxjTRmbaHZU2jslpwRL1upHvB0d9C/T6zO1tNHKf5sn+5HAy6+ZlMLdzElHBf7OcZJAd+sTNn+mcXJ2y3KDGH/s8YkooV62C2AcYcuXJjkwUAf2PAXQYXaB/DT/0d1QkqzHZmq0DJaSptAJBpcnsix/1sufTJ86bomkM4IEkx40s242A3uHiZwsTw==")
	decryptFile("testData/test.txt.enc", "testData/test2.txt", pass)
	if !deepCompare("testData/test.txt", "testData/test2.txt") {
		t.Errorf("Decrypted is not equal to plaintext")
	}*/
}
