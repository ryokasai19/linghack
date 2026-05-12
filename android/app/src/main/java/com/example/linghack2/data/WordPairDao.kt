package com.example.linghack2.data

import androidx.room.*
import com.example.linghack2.models.WordPair
import kotlinx.coroutines.flow.Flow

@Dao
interface WordPairDao {
    @Query("SELECT * FROM word_pairs ORDER BY timestamp DESC")
    fun getAllWords(): Flow<List<WordPair>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertWord(word: WordPair)

    @Update
    suspend fun updateWord(word: WordPair)

    @Delete
    suspend fun deleteWord(word: WordPair)

    @Query("DELETE FROM word_pairs")
    suspend fun deleteAll()
}
