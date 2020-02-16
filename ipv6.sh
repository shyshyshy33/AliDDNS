#!/bin/sh
aliddns_name=”你的域名前缀”
aliddns_domain=”你的域名”
aliddns_ak=”你的AccessKeyId”
aliddns_sk=”你的AccessKeySecret”
# 获取本地ipv6并与以前保存的ipv6比较
# 获取本地ipv6，我这边有三个ipv6，一个是240e开头的互联网能互相访问的，
# 一个是240e开头的临时网址，但互联网不能访问，却能访问互联网。
# 一个是fe80开头的本地ipv6，应该舍弃
# 得筛选出那个互联网能够互访的ipv6
ip=$(/sbin/ifconfig eth0 | grep 'inet6 addr' | sed 's/^.*addr://g' ) 
# 获取本地保存的已经解析过的ipv6
oldip=$(cat /root/ip.txt 2>&1)
echo $oldip
result=$(echo $ip | grep "$oldip")
if [[ "$result" != "" ]]
    then
    echo 获取的本地ipv6跟以前保存的一样，没必要解析，退出。
        exit 0
fi 
echo $ip >/root/ip.txt ##把ip替换到文件中
# 在ip.sb网站上查到一个本地ipv6，我发现，都是临时ipv6
# 不知道再有什么选择能互访的ipv6的办法？
localip=$(curl -6 ip.sb)
# 将本机三个ipv6保存进数组
OLD_IFS="$IFS"
IFS="/"
array=($ip)
IFS=$OLD_IFS
# 取掉临时的和fe80开头的ipv6，留下能互访问的ipv6
for var in ${array[@]}
  do
  result=$(echo $var | grep "fe80")
  echo var是$var
  if [[ "$result" != "" ]]
  then
    echo 是内网ipv6退出
    continue
  fi
  if [[ $var = $localip ]]
  then
    echo 是不能互访的ipv6返回
    continue
  fi
  length=${#var}
  ipv6num=16
  if [[ $length -gt $ipv6num ]];
  then
    echo 是可以互访的ipv6，退出选择
    ip=$var
    break
  else
    echo 长度太小
    continue
  fi 
done
ip=`echo $ip`
echo $ip ###正确ip
echo "数组元素个数为: ${#array[*]}"
# 安装阿里云cli
cg=$(aliyun version 2>&1)
cg=${cg:0:1}
if ! [[ "$cg" -gt 0 ]] 2>/dev/null
    then
    # 下载阿里cli
    wget https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz
    # 解压
    tar xzvf aliyun-cli-linux-latest-amd64.tgz
    # 复制到系统文件夹
    cp aliyun /usr/local/bin
    # cli初始化设置
    aliyun configure set \
    --profile akProfile \
    --mode AK \
    --region cn-hangzhou \
    --access-key-id $aliddns_ak \
    --access-key-secret $aliddns_sk
fi
# 得到解析id
get_recordid() {
    grep -Eo '"RecordId": "[0-9]+"' | cut -d':' -f2 | tr -d '"'
}
# 向阿里云域名cli获取解析id
query_recordid() {
    aliddns_record_id=`aliyun alidns  DescribeDomainRecords --DomainName $aliddns_domain --RRKeyWord $aliddns_name --Type AAAA`
  echo -n $aliddns_record_id
  }
# 修改解析
update_record() {
    aliyun alidns UpdateDomainRecord --RR $aliddns_name --RecordId $1 --Type AAAA --Value $ip
}
# 添加解析
add_record() {
    aliyun alidns AddDomainRecord --DomainName $aliddns_domain --RR $aliddns_name --Type AAAA --Value $ip
}
if [ "$aliddns_record_id" = "" ]
then
    aliddns_record_id=`query_recordid | get_recordid`
  echo $aliddns_record_id
fi
if [ "$aliddns_record_id" = "" ]
then
    aliddns_record_id=`add_record | get_recordid`
    echo "added record $aliddns_record_id"
else
    update_record $aliddns_record_id
    echo "updated record $aliddns_record_id"
