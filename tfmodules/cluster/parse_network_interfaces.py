import sys
import json


def main():
    internal_ip, internal_ifname = None, None
    external_ip, external_ifname = None, None
    for interface in json.load(sys.stdin):
        ifname = interface['ifname']
        if ifname.startswith('lo') or ifname.startswith('flannel') or ifname.startswith('nodelocal') or ifname.startswith('cali'):
            continue
        for addr_info in interface.get('addr_info', []):
            if addr_info.get('family') == 'inet':
                ip = addr_info.get('local')
                if ip:
                    if ip.startswith('172.16.'):
                        assert internal_ip is None and internal_ifname is None
                        internal_ip, internal_ifname = ip, ifname
                    else:
                        assert external_ip is None and external_ifname is None
                        external_ip, external_ifname = ip, ifname
    print(json.dumps({
        'int': {
            'ip': internal_ip,
            'if': internal_ifname
        },
        'ext': {
            'ip': external_ip,
            'if': external_ifname
        }
    }))

if __name__ == '__main__':
    main()
