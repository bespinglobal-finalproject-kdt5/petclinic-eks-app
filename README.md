# Petclinic 앱 소스

수정된 [Angular 웹](petclinic-angular/)과 [Spring REST API](petclinic-rest/)를 한 곳에 모은 저장소입니다. Terraform, Kubernetes 매니페스트, Dockerfile, Docker Compose 및 운영 자격 증명은 포함하지 않습니다. 이 저장소에 push해도 AWS에 배포되지 않습니다.

## 로컬 실행

JDK 21과 Node.js 24.x를 준비한 뒤 저장소 루트에서 각각 다른 터미널로 실행합니다.

```bash
# 터미널 1: Spring REST (기본 H2 메모리 DB)
cd petclinic-rest
./mvnw spring-boot:run
```

```bash
# 터미널 2: Angular 개발 서버
cd petclinic-angular
npm ci
npm start
```

브라우저에서 `http://localhost:4200/`을 엽니다. Angular는 `/petclinic/api/`를 호출하고 개발 서버가 이를 `127.0.0.1:9966`으로 전달합니다. REST에는 외부 PostgreSQL용 `external-postgres` 프로필도 포함돼 있습니다. 실제 비밀번호는 저장소에 기록하지 마세요.

기준 소스: [petclinic-infra의 앱 보존 커밋](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/tree/a306bdcf293ecba5cff81fcd6b32deabcb5db98b). 각 앱의 원본 저작권 고지와 라이선스는 그대로 유지합니다.
