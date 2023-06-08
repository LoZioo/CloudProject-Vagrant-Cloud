echo -----BEGIN CERTIFICATE----- > ~/.kube_certs/ca.crt
KEY=certificate-authority-data ; grep $KEY ~/.kube/config | sed -e 's/\s*'$KEY':\s*//' | fold -w67 >> ~/.kube_certs/ca.crt
echo -----END CERTIFICATE----- >> ~/.kube_certs/ca.crt

echo -----BEGIN CERTIFICATE----- > ~/.kube_certs/ca.crt
KEY=client-certificate-data ; grep $KEY ~/.kube/config | sed -e 's/\s*'$KEY':\s*//' | fold -w67 > ~/.kube_certs/client.crt
echo -----END CERTIFICATE----- >> ~/.kube_certs/ca.crt

KEY=client-key-data ; grep $KEY ~/.kube/config | sed -e 's/\s*'$KEY':\s*//' | fold -w67 > ~/.kube_certs/client.key