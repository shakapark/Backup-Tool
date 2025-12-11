package backuptool

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"io"
	"os"

	"golang.org/x/crypto/pbkdf2"
)

const bufferSize = 4096

func pKCS5Padding(ciphertext []byte, blockSize int) []byte {
	padding := blockSize - len(ciphertext)%blockSize
	padtext := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(ciphertext, padtext...)
}

func pKCS5Trimming(encrypt []byte) []byte {
	padding := encrypt[len(encrypt)-1]
	return encrypt[:len(encrypt)-int(padding)]
}

func GetPasswordFromFile(fileName string) ([]byte, error) {
	f, err := os.Open(fileName)
	if err != nil {
		return nil, err
	}

	defer f.Close()

	pass := make([]byte, 1024)
	n, err := f.Read(pass)
	if err != nil {
		return nil, err
	}
	return pass[:n-1], nil
}

func DecryptFile(fileNameIn string, fileNameOut string, password []byte) error {
	fIn, err := os.Open(fileNameIn)
	if err != nil {
		return err
	}
	defer fIn.Close()

	fOut, err := os.OpenFile(fileNameOut, os.O_CREATE|os.O_RDWR|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	defer fOut.Close()

	salt := make([]byte, 16)
	_, err = fIn.Read(salt)
	if err != nil {
		return err
	}

	derivedKey := pbkdf2.Key(password, salt[8:], 100000, 48, sha256.New)
	block, err := aes.NewCipher(derivedKey[:32])
	if err != nil {
		return err
	}

	mode := cipher.NewCBCDecrypter(block, derivedKey[32:48])

	buf := make([]byte, bufferSize)

	decryptedbuf := make([]byte, bufferSize)

	n, err := fIn.Read(buf)
	if err != nil && err != io.EOF {
		return err
	}

	nPrev := n
	// On garde un buffer de retard pour depadder le dernier en block
	previousBuf := bytes.Clone(buf[:n])
	for {
		n, err = fIn.Read(buf)
		if err != nil && err != io.EOF {
			return err
		}

		if n == 0 {
			// On retire le padding du dernier block
			mode.CryptBlocks(decryptedbuf, previousBuf[:nPrev])
			fOut.Write(pKCS5Trimming(decryptedbuf[:nPrev]))
			return nil
		} else {
			// On est pas à la fin du ficher,
			// On déchiffe le precedent block et on stocke le courant pour peut etre depadder
			mode.CryptBlocks(decryptedbuf, previousBuf)
			fOut.Write(decryptedbuf)
			previousBuf = bytes.Clone(buf[:n])
			nPrev = n
		}
	}
}

func EncryptFile(fileNameIn string, fileNameOut string, password []byte, salt []byte) error {
	fIn, err := os.Open(fileNameIn)
	if err != nil {
		return err
	}
	defer fIn.Close()

	fOut, err := os.OpenFile(fileNameOut, os.O_CREATE|os.O_RDWR|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	defer fOut.Close()

	if salt == nil {
		salt = make([]byte, 16)
		// openssl stuff
		salt[0] = 'S'
		salt[1] = 'a'
		salt[2] = 'l'
		salt[3] = 't'
		salt[4] = 'e'
		salt[5] = 'd'
		salt[6] = '_'
		salt[7] = '_'
		_, err = io.ReadFull(rand.Reader, salt[8:])
		if err != nil {
			return err
		}
	}

	_, err = fOut.Write(salt)
	if err != nil {
		return nil
	}

	derivedKey := pbkdf2.Key(password, salt[8:], 100000, 48, sha256.New)
	block, err := aes.NewCipher(derivedKey[:32])
	if err != nil {
		return err
	}

	mode := cipher.NewCBCEncrypter(block, derivedKey[32:48])

	buf := make([]byte, bufferSize)
	encryptedbuf := make([]byte, bufferSize)
	init := true
	for {
		n, err := fIn.Read(buf)
		if err != nil && err != io.EOF {
			return err
		}

		if n == 0 && !init {
			return nil
		}
		init = false
		if n < bufferSize {
			padding := aes.BlockSize - len(buf[:n])%aes.BlockSize
			// On ajoute le padding du dernier block
			mode.CryptBlocks(encryptedbuf, pKCS5Padding(buf[:n], aes.BlockSize))
			fOut.Write(encryptedbuf[:n+padding])
			return nil

		} else {
			// On est pas à la fin du ficher,
			// On chiffe le precedent block et on stocke le courant pour peut etre padder
			mode.CryptBlocks(encryptedbuf, buf)
			fOut.Write(encryptedbuf)
		}
	}
}
