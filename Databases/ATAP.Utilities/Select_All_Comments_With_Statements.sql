
SELECT C.Id as GCommentId, S.Statement as Statement FROM GComment C, GStatement S , Map_GComment_GStatement M
  WHERE M.FK_GComment = C.Id AND M.FK_GStatement = S.Id 
  order by C.Id, M.SortOrder
