#!/usr/bin/env sh

#Yandex DNS API
#https://tech.yandex.ru/pdd/doc/concepts/api-dns-docpage/
#
#YA_Token="123456789ABCDEF0000000000000000000000000000000000000"

YA_Api="https://pddimp.yandex.ru/api2/admin/dns/"

########  Public functions #####################
#Usage: add _acme-challenge.www.domain.com "123456789ABCDEF0000000000000000000000000000000000000"
dns_ya_add() {
  fulldomain=$1
  txtvalue=$2
  
  if [ -z "$YA_Token" ] ; then
    _err "You don't specify Yandex token."
    _err "Please create you token and try again."
    return 1
  fi

  #save the api key to the account conf file.
  _saveaccountconf YA_Token "$YA_Token"
  
  _debug "First detect the root zone"
  if ! _get_root $fulldomain ; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  if ! exists_record "$_domain" "$_sub_domain" ; then 
    _err "record existing check"
    return 1
  fi
  if [ ! -z "$record_id" ] ; then
    if ! edit_record "$_domain" "$_sub_domain" "$record_id" "$txtvalue" ; then
      return 1
    fi
  else
    if ! add_record "$_domain" "$_sub_domain" "$txtvalue" ; then
      return 1
    fi
  fi

  return 0
}

exists_record() {
  _debug "Getting record id if exist"
  root=$1
  sub=$2

  if ! _ya_rest "list?domain=$root" ; then
    return 1
  fi

  record_id=$(printf "$response" | _egrep_o '"record_id": \d*, "subdomain": "'$sub'"' | cut -d , -f 1 | cut -d ' ' -f 2)
  _debug record_id "$record_id"
  return 0
}

edit_record() {
  _debug "Edit exist record by id"
  root=$1
  sub=$2
  rec_id=$3
  txtvalue=$4

  if ! _ya_rest "edit" "domain=$root&record_id=$rec_id&subdomain=$sub&content=$txtvalue" ; then
    _err "Edit txt record error."
    return 1
  fi
  return 0
}

add_record() {
  _info "Adding record"
  root=$1
  sub=$2
  txtvalue=$3

  if ! _ya_rest "add" "domain=$root&type=TXT&subdomain=$sub&content=$txtvalue" ; then
    _err "Add txt record error."
    return 1
  fi
  return 0
}

####################  Private functions bellow ##################################
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  domain=$1
  i=2
  p=1
  while [ '1' ] ; do
    h=$(printf $domain | cut -d . -f $i-100)
    if [ -z "$h" ] ; then
      return 1
    fi
    
    if _ya_rest "list?domain=$h" ; then
      if printf "$response" | grep "$h" >/dev/null ; then
        _sub_domain=$(printf $domain | cut -d . -f 1-$p)
        _domain=$h
        return 0
      fi
      _debug "$h not found"
    fi

    p=$i
    i=$(expr $i + 1)
  done
  return 1
}

_ya_rest() {
  ep=$1
  data=$2

  _H1="PddToken: $YA_Token"

  if [ "$data" ] ; then
    _debug data "$data"
    response="$(_post "$data" "$YA_Api$ep" "" "POST")"
  else
    response="$(_get "$YA_Api$ep")"
  fi

  if [ "$?" != "0" ] ; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"
  if printf "$response" | grep '"success": "error"' >/dev/null ; then
    err=$(printf "$response" | cut -d '"' -f 12 )
    _err "error $ep: $err"
    return 1
  fi

  return 0
}