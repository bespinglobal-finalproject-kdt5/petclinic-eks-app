# Petclinic — Angular WEB + Spring REST API

Petclinic은 동물병원에서 **보호자, 반려동물, 방문 기록, 수의사**를 관리하는 예제 애플리케이션입니다. 이 저장소에는 EKS 환경에서 사용하도록 수정했던 두 앱의 **소스 코드**가 들어 있습니다. AWS 계정 없이도 로컬에서 두 앱을 함께 실행할 수 있습니다.

**배포 상태:** 이전 EKS·RDS 배포는 롤백했습니다. 이 저장소의 `main`에 push해도 AWS 리소스가 생성되거나 서비스가 재배포되지 않습니다. Terraform, Kubernetes 매니페스트, Dockerfile, Docker Compose, 운영 자격 증명은 포함하지 않습니다.

## 1. WEB과 WAS는 어떻게 나뉘나요?

| 구성 | 역할 | 로컬 주소 |
|---|---|---|
| [Angular WEB](petclinic-angular/) | 메뉴, 검색 결과, 등록·수정 폼을 브라우저에 표시합니다. DB에 직접 접속하지 않습니다. | `http://localhost:4200/` |
| [Spring REST API (WAS)](petclinic-rest/) | 브라우저의 요청을 검증하고 서비스·저장소 계층을 거쳐 DB에 읽고 씁니다. | `http://localhost:9966/petclinic/api/` |
| 데이터베이스 | 기본값은 예제 데이터가 들어 있는 메모리 H2입니다. 영구 저장이 필요하면 외부 PostgreSQL을 선택합니다. | API에서만 접근 |

예를 들어 **Add Owner**를 누르면 브라우저가 `POST /petclinic/api/owners`를 보냅니다. 로컬에서는 Angular 개발 서버의 [프록시 설정](petclinic-angular/proxy.conf.json)이 경로를 그대로 유지해 `127.0.0.1:9966`으로 전달합니다. Spring이 보호자를 저장하고 생성된 ID를 응답합니다. 프론트 코드에 EC2 주소나 DB 접속 정보가 필요하지 않습니다.

## 2. 처음 실행하기 — AWS·PostgreSQL 없이

**준비물:** Git, JDK 21, Node.js 24.x와 npm. Maven은 저장소에 포함된 Wrapper를 사용합니다. 아래 명령은 Bash 기준이며, Windows에서는 `./mvnw` 대신 `mvnw.cmd`를 사용할 수 있습니다.

```bash
git clone https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app.git
cd petclinic-eks-app
```

**터미널 1 — REST부터 시작합니다.** 처음 실행할 때는 Maven 의존성을 내려받습니다.

```bash
cd petclinic-rest
./mvnw spring-boot:run
```

**터미널 2 — 새 터미널을 저장소 루트에서 열고 WEB을 시작합니다.**

```bash
cd petclinic-angular
npm ci
npm start
```

브라우저에서 **<http://localhost:4200/>** 을 엽니다. 두 프로세스가 모두 떠 있어야 목록 조회와 저장이 가능합니다. 종료할 때는 각 터미널에서 `Ctrl+C`를 누르세요. 기본 H2 모드에서는 REST를 종료하면 새로 입력한 데이터가 사라집니다.

### 실행 확인

```bash
# ① REST가 요청을 받을 준비가 됐는지 확인: status가 UP이어야 합니다.
curl -fsS http://localhost:9966/petclinic/actuator/health/readiness

# ② 브라우저와 같은 경로로 확인: Angular 프록시를 거쳐 JSON 페이지를 반환해야 합니다.
curl -fsS 'http://localhost:4200/petclinic/api/v2/owners?page=0&size=1'
```

API 주소·요청 필드·응답 형식은 실행 중인 [로컬 Swagger UI](http://localhost:9966/petclinic/swagger-ui.html) 또는 [OpenAPI 명세](petclinic-rest/src/main/resources/openapi.yml)에서 확인할 수 있습니다.

## 3. 화면에서 무엇을 해볼 수 있나요?

| 메뉴·화면 | 기능 |
|---|---|
| Owners | 성으로 보호자 검색, 신규 등록, 상세 조회 및 연락처 수정 |
| 보호자 상세 → Pets / Visits | 보호자에게 반려동물 추가, 반려동물 정보 수정, 방문 기록 등록·수정·삭제 |
| Veterinarians / Specialties | 수의사와 전문 분야 관리 |
| Pet Types | 개·고양이 등 등록 폼에서 선택할 동물 종류 관리 |

**첫 실습:** `Owners → Add Owner`에서 가상 보호자를 등록하고 성으로 검색하세요. 상세 화면에서 `Add New Pet`으로 반려동물을 추가한 뒤 `Add Visit`으로 방문 기록을 남기면, 보호자 → 반려동물 → 방문 기록의 관계를 확인할 수 있습니다. 전화번호는 구분자 없이 **숫자 10자리**입니다. 빈 DB라 종류를 선택할 수 없으면 `Pet Types`에서 종류를 먼저 추가하세요. 기본 설정은 사용자 인증이 꺼져 있으므로 **실제 이름·주소·전화번호 대신 가상 데이터만** 사용하세요.

## 4. H2 대신 PostgreSQL 사용하기

로컬 화면 확인에는 H2로 충분합니다. 재시작 후에도 데이터를 유지하거나 외부 DB와 연동을 시험할 때만 `external-postgres` 프로필을 선택하세요.

1. PostgreSQL에 DB와 접속 계정을 준비합니다. **새 빈 개발 DB**라면 관리자 또는 마이그레이션 계정으로 [schema.sql](petclinic-rest/src/main/resources/db/postgres/schema.sql)을 한 번 적용하고 앱 계정에 필요한 테이블·시퀀스 권한을 부여합니다. 기존 데이터가 있는 DB에는 초기화 스크립트를 그대로 재실행하지 마세요.
2. REST 터미널에 아래 값을 설정한 뒤 재시작합니다. `POSTGRES_URL`은 일반 웹 주소가 아니라 **JDBC URL**입니다.

```bash
# petclinic-rest/에서 실행하는 로컬 PostgreSQL 예시
export SPRING_PROFILES_ACTIVE=external-postgres
export POSTGRES_URL='jdbc:postgresql://localhost:5432/petclinic'
export POSTGRES_USER='petclinic_app'
read -rsp 'PostgreSQL password: ' POSTGRES_PASS; echo
export POSTGRES_PASS
./mvnw spring-boot:run
```

이 프로필은 `spring.sql.init.mode=never`, `spring.jpa.hibernate.ddl-auto=validate`입니다. 즉, **앱은 스키마를 만들거나 샘플 데이터를 넣지 않고, 준비된 스키마가 맞는지만 검사**합니다. 원격 DB는 신뢰할 수 있는 CA로 호스트 이름까지 검증하는 TLS 연결(`sslmode=verify-full`)을 사용하고 비밀번호는 Git에 넣지 마세요. 기본 H2 모드로 돌아가려면 위 프로세스를 종료하고 `unset SPRING_PROFILES_ACTIVE POSTGRES_URL POSTGRES_USER POSTGRES_PASS` 후 다시 실행합니다.

## 5. 기존 소스에서 바뀐 부분

| 파일 | 변경 내용과 이유 |
|---|---|
| [Angular 개발 환경](petclinic-angular/src/environments/environment.ts) / [프로덕션 환경](petclinic-angular/src/environments/environment.prod.ts) | API 주소를 `http://localhost:9966/...` 대신 `/petclinic/api/`로 사용합니다. 배포된 화면이 방문자 PC의 `localhost`에 요청을 보내는 문제를 막습니다. |
| [Angular CLI 설정](petclinic-angular/angular.json) / [개발 프록시](petclinic-angular/proxy.conf.json) | `npm start`에서 같은 출처로 들어온 API 요청을 로컬 REST에 전달합니다. 이 프록시는 프로덕션 빌드에 포함되지 않습니다. |
| [index.html](petclinic-angular/src/index.html) / [Nginx 설정](petclinic-angular/nginx.conf) | 화면을 `/`에서 제공하도록 기본 경로를 맞췄습니다. Nginx는 `8080`에서 프론트 경로 새로고침을 `index.html`로 처리하지만 API를 대신 처리하지 않습니다. 실제 배포 시 `/petclinic/api/*`는 별도로 REST에 라우팅해야 합니다. |
| [Spring 기본 설정](petclinic-rest/src/main/resources/application.properties) / [외부 PostgreSQL 설정](petclinic-rest/src/main/resources/application-external-postgres.properties) | H2 실행은 유지하고, 외부 PostgreSQL 설정과 liveness/readiness 상태 검사 경로를 추가했습니다. DB 주소·계정·암호를 앱 소스에 고정하지 않습니다. |

## 6. 테스트와 빌드

각 명령 묶음은 **저장소 루트**에서 시작합니다. Angular 의존성은 먼저 `npm ci`로 설치하세요.

```bash
cd petclinic-angular
npm run test:ci                       # 단위 테스트를 한 번 실행
npm run build -- --configuration production  # 정적 웹 파일 → dist/browser/
```

```bash
cd petclinic-rest
./mvnw test                           # REST 테스트
./mvnw package                        # 테스트 후 실행 가능한 JAR → target/
```

## 7. 자주 막히는 지점

| 증상 | 확인할 것 |
|---|---|
| 화면은 열리지만 목록이 안 나오거나 프록시 오류가 납니다. | 위 실행 확인 ① → ② 순서로 호출하세요. ①부터 실패하면 REST의 기동 로그·9966 포트를, ①만 성공하면 Angular 프록시 대상과 요청 경로를 확인하세요. |
| 빈 PostgreSQL에서 `/petclinic/api/owners`가 `404`입니다. | 기존 목록 API는 결과가 없을 때도 404를 반환합니다. `/petclinic/api/v2/owners?page=0&size=1`의 `content`와 `totalElements`로 연결 여부와 데이터 유무를 구분하세요. |
| PostgreSQL 프로필에서 시작하자마자 실패합니다. | 접속 환경변수, DB·스키마 존재 여부, 앱 계정 권한을 확인하세요. `validate`는 없는 테이블을 자동 생성하지 않습니다. |

**관련 자료:** [Angular 상세 README](petclinic-angular/README.md) · [REST 상세 README](petclinic-rest/readme.md) · [앱 소스 보존 커밋과 당시 인프라 구성](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/tree/a306bdcf293ecba5cff81fcd6b32deabcb5db98b). 하위 README에는 원본 프로젝트의 Docker 안내도 남아 있지만, 이 저장소에는 해당 배포 파일이 없습니다. 각 앱의 기존 저작권 고지와 라이선스를 유지합니다.
