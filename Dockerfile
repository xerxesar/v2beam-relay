FROM centos as builder

#FIX: ```Error: Failed to download metadata for repo 'appstream': Cannot prepare internal mirrorlist: No URLs in mirrorlist```
#
  RUN cd /etc/yum.repos.d/
  RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
  RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
#
#

RUN yum install gcc make pcre-devel zlib-devel openssl-devel -y \
    && yum clean all

ENV PREFIX /opt/nginx
ENV NGX_VER 1.16.0

ENV WORKDIR /src
ENV NGX_SRC_DIR ${WORKDIR}/nginx-${NGX_VER}
ENV NGX_URL http://nginx.org/download/nginx-${NGX_VER}.tar.gz
ENV NGX_HTTP_ECHO_URL https://github.com/openresty/echo-nginx-module/archive/master.tar.gz

WORKDIR ${WORKDIR}

RUN tar zxf `curl -SLOs -w'%{filename_effective}' ${NGX_URL}` -C ${WORKDIR} \
    && tar zxf `curl -SLJOs -w'%{filename_effective}' ${NGX_HTTP_ECHO_URL}` -C ${NGX_SRC_DIR}

WORKDIR ${NGX_SRC_DIR}
ADD traffic-accounting-nginx-module traffic-accounting-nginx-module
RUN ./configure --prefix=${PREFIX} \
    --with-stream \
    --with-stream_ssl_preread_module \
    --with-stream_ssl_module \
    --with-http_ssl_module \
    --add-dynamic-module=traffic-accounting-nginx-module \
    --add-dynamic-module=echo-nginx-module-master \
    --http-log-path=/dev/stdout \
    --error-log-path=/dev/stderr \
    && make -s && make -s install


FROM centos

ENV PREFIX /opt/nginx
ENV CONFIG_VER $(date)

COPY --from=builder ${PREFIX} ${PREFIX}

WORKDIR ${PREFIX}

RUN ln -sf /dev/stdout ${PREFIX}/logs/access.log \
    && ln -sf /dev/stderr ${PREFIX}/logs/http-accounting.log \
    && ln -sf /dev/stderr ${PREFIX}/logs/stream-accounting.log \
    && ln -sf /dev/stderr ${PREFIX}/logs/error.log \
    && ln -sf ../usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ADD nginx.conf ${PREFIX}/conf/nginx.conf
ADD http.conf ${PREFIX}/conf/http.conf
ADD stream.conf ${PREFIX}/conf/stream.conf

RUN mkdir /usr/share/html
ADD index.html /usr/share/html/


EXPOSE 443
EXPOSE 80
STOPSIGNAL SIGTERM
ENTRYPOINT ["./sbin/nginx", "-g", "daemon off;"]
