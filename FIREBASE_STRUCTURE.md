# Firebase Firestore 구조

## 데이터베이스 구조

### 1. Groups 컬렉션
**경로:** `users/{userId}/groups/{groupId}`

각 사용자의 단어 그룹을 관리합니다.

```typescript
{
  name: string,              // 그룹 이름 (예: "2024-01-15 단어장", "토익 단어")
  date: string,              // 날짜 (YYYY-MM-DD 형식, 예: "2024-01-15")
  createdAt: Timestamp,      // 그룹 생성 시간
  updatedAt: Timestamp       // 그룹 수정 시간
}
```

**사용 예시:**
- 날짜별로 단어를 분류할 수 있습니다
- 주제별로 단어를 분류할 수 있습니다 (예: "토익", "회화")
- 그룹별로 단어 목록을 조회할 수 있습니다

### 2. Flashcards 컬렉션
**경로:** `users/{userId}/flashcards/{wordDocId}`

**문서 ID 형식:** `{groupId}_{word}` (예: "abc123_acknowledge")

각 단어의 정보를 저장합니다. 한 단어는 여러 그룹에 속할 수 있습니다.

```typescript
{
  word: string,                    // 단어 (예: "acknowledge")
  meaning: {                       // 단어의 의미 (원본 Firestore에서 가져온 구조 유지)
    definition: string | string[], // 정의
    examples: string | string[]    // 예문
  },
  groups: string[],                // 속한 그룹 ID 배열 (한 단어가 여러 그룹에 속할 수 있음)
  difficulty: string,              // 난이도: "easy" | "normal" | "hard"
  viewCount: number,               // 본 횟수 (기본값: 0)
  createdAt: Timestamp,            // 단어 첫 생성 시간 (날짜 필터링 시 이 필드에서 날짜 추출)
  updatedAt: Timestamp             // 단어 마지막 수정 시간
}
```

## 주요 기능

### 1. 그룹 관리
- **그룹 선택**: 기존 그룹 중 하나를 선택하여 단어를 추가
- **그룹 생성**: 새 그룹을 생성하여 단어를 추가
- **날짜 지정**: 그룹에 날짜를 지정하여 날짜별로 단어를 필터링 가능

### 2. 단어 관리
- **난이도 설정**: 각 단어마다 easy/normal/hard 난이도 설정
- **viewCount**: 단어를 본 횟수 추적 (앱을 켰을 때 낮은 순서로 보여줄 수 있음)
- **다중 그룹**: 한 단어가 여러 그룹에 속할 수 있음

### 3. 쿼리 예시

#### 그룹별 단어 조회
```dart
_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .where('groups', arrayContains: groupId)
  .get();
```

#### 날짜별 단어 조회
```dart
// createdAt Timestamp에서 날짜 추출하여 필터링
final targetDate = DateTime(2024, 1, 15);
final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
final endOfDay = startOfDay.add(const Duration(days: 1));

_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
  .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
  .get();

// 또는 클라이언트에서 필터링
final snapshot = await _firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .get();

final wordsOnDate = snapshot.docs.where((doc) {
  final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
  if (createdAt == null) return false;
  return createdAt.year == targetDate.year &&
         createdAt.month == targetDate.month &&
         createdAt.day == targetDate.day;
}).toList();
```

#### 난이도별 단어 조회 및 정렬
```dart
// 어려운 단어만
_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .where('difficulty', isEqualTo: 'hard')
  .get();

// viewCount 오름차순 정렬 (적게 본 순서)
_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .orderBy('viewCount', descending: false)
  .get();

// 난이도별 + viewCount 정렬
_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .where('difficulty', isEqualTo: 'hard')
  .orderBy('viewCount', descending: false)
  .get();
```

**참고:** Firestore에서 날짜별 필터링 시 `createdAt` Timestamp를 사용합니다:
- 날짜 추출: `timestamp.toDate()` 후 `year`, `month`, `day` 속성 사용
- 또는 Timestamp 범위 쿼리 사용 (위 예시 참고)

#### 앱을 켰을 때 보여줄 단어 (viewCount가 적은 순서)
```dart
_firestore
  .collection('users')
  .doc(userId)
  .collection('flashcards')
  .orderBy('viewCount', descending: false)
  .limit(20)  // 상위 20개만
  .get();
```

## 데이터 저장 시 주의사항

1. **문서 ID**: `{groupId}_{word}` 형식으로 생성하여 같은 단어가 여러 그룹에 있을 때 구분
2. **groups 배열**: 단어가 여러 그룹에 속할 수 있으므로 배열로 관리
3. **viewCount**: 기존 값이 있으면 유지, 없으면 0으로 시작
4. **createdAt**: 첫 생성 시에만 설정, 이후 업데이트에서는 유지 (날짜 필터링 시 이 필드에서 날짜 추출)

## 인덱스 필요

Firestore에서 다음 인덱스가 필요할 수 있습니다:

1. `groups` (Array) + `viewCount` (Ascending)
2. `difficulty` (String) + `viewCount` (Ascending)
3. `createdDate` (String) + `viewCount` (Ascending)

복합 쿼리를 사용할 경우 Firestore 콘솔에서 인덱스를 생성해야 합니다.

