#!/usr/bin/zsh

mkdir -p recon-$1
cd recon-$1 || exit
echo -e "\n===========================\n run assetfinder .... \n===========================\n" 
assetfinder -subs-only $1 | tee  sub.txt
echo -e "\n===========================\n run subfinder .... \n===========================\n" 
subfinder -silent -d $1 -all | tee -a sub.txt
echo -e "\n===========================\n run crt.sh .... \n===========================\n" 
curl -s "https://crt.sh/json?q=$1" |tee|jq -r '.[].common_name' |sort -u |tee -a sub.txt
echo -e "\n===========================\n run dnsgen .... \n===========================\n"
dnsgen=$(dnsgen sub.txt | tee dnsgen.txt)
echo -e "\n===========================\n number of subdomains .... \n===========================\n"
cat sub.txt dnsgen.txt |sort -u|tee all-sub.txt
cat all-sub.txt | wc -l
split -d  -l 10000 all-sub.txt part- 
echo -e "\n===========================\n prepare resolvers .... \n===========================\n"
echo '8.8.8.8' |tee rdns.txt
echo '1.1.1.1' |tee -a rdns.txt
echo -e "\n===========================\n run shuffledns .... \n===========================\n"
for sub in $(ls part-*) ;do  cat $sub| shuffledns -r  rdns.txt -mode resolve  -silent|tee -a live.txt ;done
cat live.txt | wc -l
echo -e "\n===========================\n  run dnsx ip .... \n===========================\n"
cat live.txt| dnsx -ro -a  -r rdns.txt -silent|tee -a ip.txt 
echo -e "\n===========================\n run httpx .... \n===========================\n"
http=$(cat live.txt |httpx-toolkit -json |tee http.txt) 
echo -e "\n code 200\n"
cat http.txt | jq -r 'select(."status-code" >= 200 and ."status-code" < 300)|.url'|tee 200.txt
echo -e "\n code 300\n"
cat http.txt |jq -r 'select(."status-code" >= 300 and ."status-code" < 400)|.url'|tee 300.txt

echo -e "\n code 400\n"

cat http.txt | jq -r'select(."status-code" >= 400 and ."status-code" < 500)|.url'|tee 400.txt
echo -e "\n code 500\n"

cat http.txt | jq -r 'select(."status-code" >= 500 and ."status-code" < 600)|.url'|tee 500.txt
rm -rf sub.txt  all-sub.txt rdns.txt dnsgen.txt  part-* resume.cfg  http.txt 
