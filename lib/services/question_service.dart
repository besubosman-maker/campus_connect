import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_question_model.dart';
import '../models/user_model.dart';

class QuestionService {
  final CollectionReference _questionsRef =
      FirebaseFirestore.instance.collection('listing_questions');

  // Stream all questions for a given listing
  Stream<List<ListingQuestionModel>> getQuestionsStream(String listingId) {
    return _questionsRef
        .where('listingId', isEqualTo: listingId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ListingQuestionModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      // Sort: answered questions first, then by date descending
      list.sort((a, b) {
        if (a.isAnswered && !b.isAnswered) return -1;
        if (!a.isAnswered && b.isAnswered) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  // Ask a new public question
  Future<void> askQuestion({
    required String listingId,
    required String sellerId,
    required String question,
    required UserModel asker,
  }) async {
    final docRef = _questionsRef.doc();
    final newQuestion = ListingQuestionModel(
      id: docRef.id,
      listingId: listingId,
      askerId: asker.uid,
      askerName: asker.name.isNotEmpty ? asker.name : 'Student',
      question: question.trim(),
      sellerId: sellerId,
      createdAt: DateTime.now(),
    );

    await docRef.set(newQuestion.toMap());
  }

  // Seller answers a question
  Future<void> answerQuestion({
    required String questionId,
    required String answer,
  }) async {
    await _questionsRef.doc(questionId).update({
      'answer': answer.trim(),
      'answeredAt': Timestamp.now(),
    });
  }

  // Upvote or remove upvote
  Future<void> toggleUpvote({
    required String questionId,
    required String userId,
  }) async {
    final docRef = _questionsRef.doc(questionId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;
    final List<dynamic> upvotedUsers = List.from(data['upvotedUserIds'] ?? []);
    int currentUpvotes = (data['upvotes'] as num?)?.toInt() ?? 0;

    if (upvotedUsers.contains(userId)) {
      upvotedUsers.remove(userId);
      currentUpvotes = (currentUpvotes - 1).clamp(0, 9999);
    } else {
      upvotedUsers.add(userId);
      currentUpvotes += 1;
    }

    await docRef.update({
      'upvotes': currentUpvotes,
      'upvotedUserIds': upvotedUsers,
    });
  }
}
